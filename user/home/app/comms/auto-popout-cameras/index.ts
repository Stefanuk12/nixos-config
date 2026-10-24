/*
 * Vencord, a Discord client mod
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType } from "@utils/types";
import { findByPropsLazy, findStoreLazy } from "@webpack";
import { PopoutWindowStore, SelectedChannelStore, UserStore } from "@webpack/common";

// openCallTilePopout(channelId, participantId) is the path the tile's own "Pop Out" button takes:
// it dispatches CALL_TILE_POPOUT_WINDOW_OPEN, and the window opens under the key
// `DISCORD_CALL_TILE_POPOUT_${channelId}_${participantId}` — one OS window per person, which is
// what lets the Hyprland side drop each into its own corner. Vesktop only honours a popout whose
// frame name starts with DISCORD_, hence the prefix; match on the tail rather than assume it.
const CallPopouts = findByPropsLazy("openCallTilePopout", "openChannelCallPopout");
const ChannelRTCStore = findStoreLazy("ChannelRTCStore");

const settings = definePluginSettings({
    includeSelf: {
        type: OptionType.BOOLEAN,
        description: "Pop out your own camera too",
        default: false
    },
    closeWhenCameraOff: {
        type: OptionType.BOOLEAN,
        description: "Close a popout when that camera goes off or the person leaves",
        default: true
    },
    limit: {
        type: OptionType.SLIDER,
        description: "Most popouts to open at once",
        markers: [1, 2, 3, 4, 5, 6, 8],
        default: 4,
        stickToMarkers: true
    }
});

// Participants we opened a window for, and ones whose window the user closed by hand: reopening
// those on the next store change would make the close button useless. A camera going off clears
// the grudge, so turning it back on pops out again.
const opened = new Set<string>();
const dismissed = new Set<string>();

const windowKeys = (): string[] => PopoutWindowStore.getWindowKeys?.() ?? [];
const keyFor = (channelId: string, id: string) =>
    windowKeys().find(k => k.endsWith(`_${channelId}_${id}`));

function closeAll() {
    for (const key of windowKeys()) {
        if (key.includes("CALL_TILE_POPOUT_")) CallPopouts.close(key);
    }
    opened.clear();
    dismissed.clear();
}

function sync() {
    const channelId = SelectedChannelStore.getVoiceChannelId();
    if (!channelId) return closeAll();

    const selfId = UserStore.getCurrentUser()?.id;
    const live: any[] = ChannelRTCStore.getVideoParticipants(channelId) ?? [];
    const wanted = live
        .filter(p => settings.store.includeSelf || (p.user?.id ?? p.id) !== selfId)
        .slice(0, settings.store.limit);
    const liveIds = new Set(wanted.map(p => p.id));

    for (const id of [...opened]) {
        if (liveIds.has(id)) {
            if (!keyFor(channelId, id)) {
                opened.delete(id);
                dismissed.add(id);
            }
            continue;
        }
        opened.delete(id);
        dismissed.delete(id);
        if (settings.store.closeWhenCameraOff) {
            const key = keyFor(channelId, id);
            if (key) CallPopouts.close(key);
        }
    }

    for (const p of wanted) {
        if (opened.has(p.id) || dismissed.has(p.id)) continue;
        opened.add(p.id);
        if (!keyFor(channelId, p.id)) CallPopouts.openCallTilePopout(channelId, p.id);
    }
}

// Both stores churn during a call (speaking flags, volume, layout), so coalesce; Discord also
// needs a beat after a camera comes up before the participant is in the video list.
let timer: ReturnType<typeof setTimeout> | undefined;
const schedule = () => {
    clearTimeout(timer);
    timer = setTimeout(sync, 400);
};

export default definePlugin({
    name: "AutoPopoutCameras",
    description: "Pops every camera in the call out into its own window, one per person",
    authors: [{ name: "stefan", id: 0n }],
    settings,

    start() {
        ChannelRTCStore.addChangeListener(schedule);
        SelectedChannelStore.addChangeListener(schedule);
        schedule();
    },

    stop() {
        ChannelRTCStore.removeChangeListener(schedule);
        SelectedChannelStore.removeChangeListener(schedule);
        clearTimeout(timer);
        closeAll();
    }
});
