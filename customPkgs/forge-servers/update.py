#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests

#NOTES
# my research seems to suggest forge can come in 3 varieties:
# ancient: this version only happens with *very* old versions (pre 1.5) and 
#    I *think* is just files to drop over the client.jar. very old method and one
#    we can probably save till the other two are working
# universal: This version comes with two files, universal.jar, and installer.jar
#    the first is the actual forge launcher, while the latter grabs the files
#    and libraries needed first.  I *think* the needed files are listed in
#    version.json inside the installer, and universal.jar is able to be
#    grabbed seperatly, so we don't need to fetch the installer during install
#    only when updating the lock files (which hopefully is never an issue, since
#    forge doesn't use this format anymore)
# modern: This version is just the installer.jar, and does some funky stuff to
#    finish the install, namely patching the actual client.jar directly
#    rather than using the pre-1.13 methods.  This one needs some work to make
#    happy, including patching the install_profile.json to remove the mapping
#    download step (because it doesn't work in a hermetic environment), and
#    stripping the hashes to make java happy.  We also need to fetch libraries as
#    with the above one, but the number of libraries is *massive*, so proper cache
#    is essential.  I'm also not 100% sure what patching methods are needed for each one,
#    so they may need some attention for current and future builds.

import json
import requests
from zipfile import ZipFile
from pathlib import Path
from requests.adapters import HTTPAdapter, Retry

MC_ENDPOINT = "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"
ENDPOINT = "https://files.minecraftforge.net/net/minecraftforge/forge/"
MAVEN = "https://maven.minecraftforge.net/net/minecraftforge/forge/"
MC_MAVEN = "https://maven.minecraftforge.net/net/minecraftforge/forge/"

TIMEOUT = 5
RETRIES = 5

class TimeoutHTTPAdapter(HTTPAdapter):
    def __init__(self, *args, **kwargs):
        self.timeout = TIMEOUT
        if "timeout" in kwargs:
            self.timeout = kwargs["timeout"]
            del kwargs["timeout"]
        super().__init__(*args, **kwargs)

    def send(self, request, **kwargs):
        timeout = kwargs.get("timeout")
        if timeout is None:
            kwargs["timeout"] = self.timeout
        return super().send(request, **kwargs)


def make_client():
    http = requests.Session()
    retries = Retry(total=RETRIES, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    http.mount('https://', TimeoutHTTPAdapter(max_retries=retries))
    http.verify = False
    return http


def get_launcher_versions(client):
    print("Fetching launcher versions")
    data = client.get(f"{ENDPOINT}/maven-metadata.json").json()
    return data

def get_game_versions(client):
    print("Fetching launcher versions")
    data = client.get(MC_ENDPOINT).json()
    return data["versions"]

def get_launcher_build(client,version):
    #print("Fetching launcher build")
    data = client.get(f"{ENDPOINT}/{version}/meta.json").json()
    return data

import io

def get_launcher_libraries(client, version):
    print("Fetching installer")
    installer_response = client.get(f"{MAVEN}/{version}/forge-{version}-installer.jar")
    installer_content = io.BytesIO(installer_response.content)
    libraries = []
    with ZipFile(installer_content) as zip:
        with zip.open("install_profile.json") as profile:
            profile_data = json.load(profile)
            libraries.extend(profile_data['libraries'])
        with zip.open("version.json") as version_file:
            version_data = json.load(version_file)
            libraries.extend(version_data['libraries'])
    return libraries

def get_game_libraries(client,version):
    print("Fetching installer")
    manifest = client.get(f"{MC_ENDPOINT}/")
    libraries = []
    return libraries

def main(launcher_versions, game_versions, library_versions, client):
    output = {}
    print("Starting fetch")

    game_manifest = get_game_versions(client)

    #We need all the libraries for a given game version for forge to be happy.  This might
    #be useful to port up to build-support.
    for version in game_manifest:
        if version['type'] == "release":
            if version['id'] in game_versions and game_versions[version['id']]['sha1'] == version['sha1']:
                pass
            else:
                data = client.get(version['url']).json()
                libraries = []
                for library in data['libraries']:
                    if not library['name'] in library_versions:
                        #I should verify nix is happy with the hashes left in these paths.
                        #If not, I need to do something like quilt's prefetch
                        if 'artifact' in library['downloads']:
                            library_versions[library['name']] = library['downloads']['artifact']
                        #Some libraries are system dependent. I'm assuming there isn't gonna be
                        #support for darwin on this, so I ignore those and only grab the linux
                        #natives.  If this is a wrong assumption, this is the place to fix it.
                        elif 'classifiers' in library['downloads']:
                            if 'natives-linux' in library['downloads']['classifiers']:
                                library_versions[library['name']] = library['downloads']['classifiers']['natives-linux']
                        #I've got some escape hatches for when libraries somehow don't match the above
                        #I don't think any *should*, but just incase, lets get some info
                        else:
                            print(version['id'])
                            print(json.dumps(library,indent=4))
                    libraries.append(library['name'])
                mappings = ""
                server = ""
                #if we don't have a server, we might just mark the version as unavailable?
                #this is server only after all.
                if 'server' in data['downloads']:
                    server=data['downloads']['server']
                #mappings are only used on the modern forge builds
                if 'server_mappings' in data['downloads']:
                    mappings=data['downloads']['server_mappings']
                game_versions[version['id']] = {
                    "sha1": version['sha1'],
                    "server": server,
                    "mappings": mappings,
                    "libraries": libraries
                }

    launcher_manifest = get_launcher_versions(client)

    for version,builds in launcher_manifest.items():
        if not version in launcher_versions:
            launcher_versions[version] = {}
        for build in builds:
            if build != "1.20.1-47.3.12":
                continue

            if not build in launcher_versions[version]:
                launcher_build = get_launcher_build(client,build)
                #TODO: need to add the actual parsers for the installer, so we can
                #      get those wonderful libraries.
                if 'universal' in launcher_build['classifiers']:
                    build_number = build.split("-")[1]
                    build_universal_hash = launcher_build['classifiers']["universal"]["jar"]
                    build_universal_url = f"{MAVEN}/{build}/forge-{build}-universal.jar"
                    build_installer_hash = launcher_build['classifiers']["installer"]["jar"]
                    build_installer_url = f"{MAVEN}/{build}/forge-{build}-installer.jar"
                    launcher_versions[version][build_number] = {
                        "type": "universal",
                        "universalUrl": build_universal_url,
                        "universalHash": build_universal_hash,
                        "installUrl": build_installer_url,
                        "installHash": build_installer_hash,
                    }
                elif 'installer' in launcher_build['classifiers']:
                    build_number = build.split("-")[1]
                    build_sha256 = launcher_build['classifiers']["installer"]["jar"]
                    build_url = f"{MAVEN}/{build}/forge-{build}-installer.jar"
                    launcher_versions[version][build_number] = {
                        "type": "modern",
                        "url": build_url,
                        "hash": build_sha256,
                    }
                elif 'client' in launcher_build['classifiers']:
                    build_number = build.split("-")[1]
                    build_sha256 = launcher_build['classifiers']["client"]["zip"]
                    build_url = f"{MAVEN}/{build}/forge-{build}-client.zip"
                    launcher_versions[version][build_number] = {
                        "type": "ancient",
                        "url": build_url,
                        "hash": build_sha256,
                    }
                else:
                    print(f'no installer or client in {build}')
                    print(launcher_build)

                # Fetch Forge libraries
                forge_libraries = get_launcher_libraries(client, build)
                for library in forge_libraries:
                    library_versions[library['name']] = library['downloads']['artifact']
                    game_versions[version]['libraries'].append(library['name'])

    #print(launcher_versions)
    return (launcher_versions,game_versions,library_versions)


if __name__ == "__main__":
    folder = Path(__file__).parent
    launcher_path = folder / "lock_launcher.json"
    game_path = folder / "lock_game.json"
    library_path = folder / "lock_libraries.json"
    with (
        open(launcher_path, "r") as launcher_locks,
        open(game_path, "r") as game_locks,
        open(library_path, "r") as library_locks,
    ):
        launcher_versions = {} if launcher_path.stat().st_size == 0 else json.load(launcher_locks)
        game_versions = {} if game_path.stat().st_size == 0 else json.load(game_locks)
        library_versions = {} if library_path.stat().st_size == 0 else json.load(library_locks)
    (launcher_versions,game_versions,library_versions) = main(
        launcher_versions,
        game_versions,
        library_versions,
        make_client(),
    )
    with (
        open(launcher_path, "w") as launcher_locks,
        open(game_path, "w") as game_locks,
        open(library_path, "w") as library_locks,
    ):
        json.dump(launcher_versions,launcher_locks,indent=4)
        json.dump(game_versions,game_locks,indent=4)
        json.dump(library_versions,library_locks,indent=4)
