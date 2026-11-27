"""
adf_parser.py
Parses Jira's Atlassian Document Format (ADF) into clean, structured sections.
"""
import json


def extract_text_from_node(node):
    if node is None:
        return ""
    
    node_type = node.get("type")
    
    if node_type == "text":
        return node.get("text", "")
    
    content = node.get("content", [])
    parts = [extract_text_from_node(child) for child in content]
    
    if node_type in ("bulletList", "orderedList"):
        return "\n".join(f"- {p}" for p in parts if p.strip())
    
    return "".join(parts)


def parse_adf_description(adf_doc):
    if adf_doc is None:
        return {"intro": "", "sections": {}}
    
    content = adf_doc.get("content", [])
    
    sections = {}
    intro_parts = []
    current_section_name = None
    current_section_parts = []
    
    def flush_current_section():
        if current_section_name is not None:
            text = "\n".join(p for p in current_section_parts if p.strip())
            if current_section_name in sections:
                sections[current_section_name] += "\n" + text
            else:
                sections[current_section_name] = text
    
    for node in content:
        node_type = node.get("type")
        
        if node_type == "heading":
            flush_current_section()
            current_section_name = extract_text_from_node(node).strip()
            current_section_parts = []
        else:
            text = extract_text_from_node(node)
            if current_section_name is None:
                intro_parts.append(text)
            else:
                current_section_parts.append(text)
    
    flush_current_section()
    
    return {
        "intro": "\n".join(p for p in intro_parts if p.strip()),
        "sections": sections
    }


def get_section(parsed, name_contains, default=""):
    name_contains_lower = name_contains.lower()
    for section_name, section_text in parsed["sections"].items():
        if name_contains_lower in section_name.lower():
            return section_text
    return default


# ---- كود التجربة ----
if __name__ == "__main__":
    with open("SYNTECH-12.json", "r", encoding="utf-8") as f:
        issue = json.load(f)

    description_adf = issue["fields"]["description"]
    parsed = parse_adf_description(description_adf)

    print("INTRO:", parsed["intro"])
    print()
    for name, text in parsed["sections"].items():
        print(f"--- {name} ---")
        print(text)
        print()

    print("Acceptance/Verification:", get_section(parsed, "criteria"))