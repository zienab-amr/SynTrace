# Apply the SynTrace Chat feature

This patch adds the AI Assistant as a separate, organized feature folder. It does not include changes to Login, Register, OTP, global routing, theme styles, or dashboard CSS.

## Files in this patch

- `src/components/Chat/` — the complete, self-contained chat feature.
- `src/components/Workspace/WorkspacePlaceholder.jsx` — the workspace component with a minimal AI Assistant navigation entry and ChatPage mounting.

## Install

1. Extract this ZIP at the root of your existing SynTrace React project.
2. Allow it to add the `src/components/Chat/` folder and replace `src/components/Workspace/WorkspacePlaceholder.jsx`.
3. Do not replace `workspace-dashboard.css`, `App.jsx`, auth files, or router files.
4. Run `npm run dev`.
5. Open your local workspace and click **AI Assistant** in the left navigation or the AI Assistant shortcut in the top bar.

## Preview without a backend

When using the local development preview mode already in the project, open `/app?preview=1`. Chat conversations and cited source records are sample data. Sending a new message displays a local-preview notice rather than pretending a live AI response was generated.

## Customization map

- Visual theme, transitions, layout and responsive behavior: `src/components/Chat/chat.css`
- Page state and local interactions: `src/components/Chat/ChatPage.jsx`
- Conversation data and source examples: `src/components/Chat/data/chatDemoData.js`
- Individual UI pieces: `src/components/Chat/components/`

No additional npm package is required by the Chat folder.
