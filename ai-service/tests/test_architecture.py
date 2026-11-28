"""The layering of the meetings package (see meetings/__init__.py): inner layers never import outer ones,
and the domain modules import no graph, web or model client. Checked from the source, so a new import
that breaks the rule fails here before review."""
import ast
import os
import sys
import unittest

HERE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "syntrace_ai")
STDLIB = set(sys.stdlib_module_names)
OUTER = {"meeting_notes", "meeting_agent", "ai_service", "query_engine", "graph_agent", "knowledge_worker",
         "fastapi", "neo4j", "requests", "groq", "openai", "llm_client", "answer_generator", "embeddings"}


def imports(path):
    with open(os.path.join(HERE, path), encoding="utf-8") as f:
        tree = ast.parse(f.read())
    found = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            found |= {a.name for a in node.names}
        elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
            found.add(node.module)
    return found


class Layering(unittest.TestCase):
    def test_domain_modules_use_only_the_standard_library_and_each_other(self):
        allowed = {"syntrace_ai", "syntrace_ai.meetings", "syntrace_ai.meetings.errors", "syntrace_ai.meetings.text", "syntrace_ai.meetings.notes", "pypdf"}
        for path in ("meetings/errors.py", "meetings/text.py", "meetings/prompts.py", "meetings/notes.py",
                     "meetings/chat_meeting.py", "meetings/document.py"):
            bad = {m for m in imports(path) if m.split(".")[0] not in STDLIB and m not in allowed}
            self.assertFalse(bad, f"{path} imports {bad}")

    def test_the_writer_and_the_session_take_the_model_as_a_function(self):
        for path in ("meetings/writer.py", "meetings/session.py"):
            if not os.path.exists(os.path.join(HERE, path)):
                continue
            top = {m.rsplit(".", 1)[-1] for m in imports(path)}
            self.assertFalse(top & (OUTER - {"llm_client"}) - {"meetings", "syntrace_ai"}, f"{path} imports {top & OUTER}")

    def test_the_memory_never_reaches_the_web_or_a_model(self):
        top = {m.rsplit(".", 1)[-1] for m in imports("meetings/memory.py")} | {m.split(".")[0] for m in imports("meetings/memory.py")}
        self.assertFalse(top & {"fastapi", "llm_client", "groq", "openai", "requests", "meeting_notes"})



if __name__ == "__main__":
    unittest.main()
