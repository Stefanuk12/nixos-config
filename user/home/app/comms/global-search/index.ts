/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 AtomicByte/Jaisal
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// Upstream: https://github.com/Atom1cByte/Global-Search
// Vendored as a userplugin. Only change from upstream: the author is inlined
// below instead of referencing `Devs.atomic`, which does not exist in stock
// Vencord's `Devs` constant and would break the build.

import definePlugin from "@utils/types";

import { MessageSearchChatBarIcon } from "./MessageSearchChatBarIcon";

export default definePlugin({
    name: "Global Search",
    description: "Search through messages in all DM channels and group DMs globally",
    authors: [{ name: "AtomicByte", id: 0n }],
    renderChatBarButton: MessageSearchChatBarIcon
});
