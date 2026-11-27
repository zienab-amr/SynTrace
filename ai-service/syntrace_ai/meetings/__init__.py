"""
meetings
The meeting agent, in layers (inner layers never import outer ones; test_architecture.py checks it):

  errors.py, text.py, prompts.py   domain: pure rules on text (masking, evidence, blame guard) and the
                                   prompts with their versions. No graph, no web, no model client.
  writer.py                        the second extraction step: each requirement as a user story, with
                                   checked priority and acceptance criteria. Takes the model as a function.
  memory.py                        the requirement memory across meetings (graph writes inside the
                                   caller's transaction) and the history the assistant tells.
  session.py                       the live meeting helper: the transcript so far in, only new help out.

  meeting_notes.py (top level)     the application service and its Neo4j repository: submit, process,
                                   review, delete, search. meeting_agent.py compares and plans.
  llm_client.py (top level)        the one model port: provider and model per step from config.
  ai_service.py (top level)        the HTTP adapter: the only place that turns requests into calls.
"""
