# SynTrace Chat

The AI Assistant is maintained as an isolated feature under `src/components/Chat/`.

## Structure

- `ChatPage.jsx` — page-level state, conversation selection, scope and source drawer state.
- `chat.css` — all chat-specific layout, responsive behavior and visual styling.
- `components/ChatSidebar.jsx` — conversation history and search.
- `components/ChatHeader.jsx` — project scope and chat actions.
- `components/MessageThread.jsx` — message list.
- `components/MessageBubble.jsx` — user and assistant message presentation.
- `components/ChatComposer.jsx` — message input and send behavior.
- `components/ContextPanel.jsx` — on-demand source inspector drawer.
- `components/ChatIcons.jsx` — local SVG icon set.
- `data/chatDemoData.js` — suggested prompt shortcuts only; conversation history and answers are loaded from the authenticated API.

## Visual behavior

The page uses a focused two-column layout: conversation history and one primary chat canvas. Source details are closed by default and open as an overlay only when a cited source is selected or the Sources action is used. Supporting findings and next steps are collapsed inside each assistant response to avoid repeating information in the conversation and source inspector.

The feature inherits the global SynTrace theme tokens from `src/index.css` and includes local fallbacks. It does not require an additional package.

## Backend integration

Conversation history is loaded from `GET /api/assistant/conversations`, message history from `GET /api/assistant/conversations/{id}/messages`, and new turns are sent to `POST /api/assistant/ask`. The frontend does not fabricate assistant answers. Draft conversations remain local until the backend returns a persisted conversation ID; only persisted IDs are used for history requests. Source references are rendered from the links returned by the assistant API.


## Workspace integration and brand usage

- The chat route fills the existing workspace viewport; it no longer adds a second outer card, border, shadow, or rounded frame inside the rounded application shell.
- Workspace padding is cleared only while `.st-chat-page` is the direct workspace view.
- All SynTrace marks in the chat use the existing `/assets/syntrace-mark.webp` brand asset from `public/assets`; no replacement mark is drawn in the chat feature.
- Chat-specific styles and components remain inside this folder.
