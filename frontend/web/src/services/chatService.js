import { ENDPOINTS } from '../config/api.js';
import { request } from './apiClient.js';

export const chatService = {
  listConversations: () => request(ENDPOINTS.assistantConversations),
  getMessages: (id) => request(`${ENDPOINTS.assistantConversations}/${encodeURIComponent(id)}/messages`),
  ask: ({ question, conversationId }) => request(ENDPOINTS.assistantAsk, { method: 'POST', body: { question, conversationId: conversationId || null } }),
  deleteConversation: (id) => request(`${ENDPOINTS.assistantConversations}/${encodeURIComponent(id)}`, { method: 'DELETE' }),
};
