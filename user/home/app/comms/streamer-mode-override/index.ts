/*
 * Vencord, a Discord client mod
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import definePlugin from "@utils/types";
import { FluxDispatcher } from "@webpack/common";

// Discord's "Automatically Enable/Disable" is a pure function of "is a detected streaming app
// running", re-evaluated whenever the running-game list changes, so turning streamer mode off by
// hand is undone within seconds while OBS stays open. There is no manual-override state to set.
//
// Auto and manual toggles arrive as the same STREAMER_MODE_UPDATE dispatch with nothing to tell
// them apart, so this doesn't try: any disable arms the override, and while armed every re-enable
// is undone. The override is disarmed once the detected app is gone, which is the point Discord
// would have turned streamer mode off anyway.

let overridden = false;

const isStreamingApp = (name: unknown) => typeof name === "string" && /\bobs\b|obs[- ]?studio/i.test(name);

function stillRunning(payload: any): boolean {
    const games = payload?.games ?? payload?.runningGames ?? [];
    return Array.isArray(games) && games.some((g: any) => isStreamingApp(g?.name) || isStreamingApp(g?.exeName));
}

export default definePlugin({
    name: "StreamerModeManualOverride",
    description: "Keeps streamer mode off once you turn it off, even while OBS is still running",
    authors: [{ name: "stefan", id: 0n }],

    flux: {
        STREAMER_MODE_UPDATE({ key, value }: { key: string; value: boolean; }) {
            if (key !== "enabled") return;

            if (!value) {
                overridden = true;
                return;
            }

            if (!overridden) return;

            // Deferred: re-entering the dispatcher from inside a handler is not allowed.
            setTimeout(() => FluxDispatcher.dispatch({ type: "STREAMER_MODE_UPDATE", key: "enabled", value: false }), 0);
        },

        RUNNING_GAMES_CHANGE(payload: any) {
            if (!stillRunning(payload)) overridden = false;
        }
    }
});
