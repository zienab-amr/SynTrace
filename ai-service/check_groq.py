"""Show the Groq rate limit state of the configured model and which models are available."""
import os

from dotenv import load_dotenv
from groq import APIStatusError, Groq

load_dotenv()
MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")


def show_limits(headers):
    for name in sorted(headers):
        if name.startswith("x-ratelimit") or name == "retry-after":
            print(f"  {name}: {headers[name]}")


def main():
    client = Groq(api_key=os.getenv("GROQ_API_KEY"), timeout=30, max_retries=0)
    print("model:", MODEL)
    # About the size of one real question. A small call can pass even when the daily budget is low.
    prompt = "Reply with OK. " + "ticket status assignee summary " * 300
    try:
        raw = client.chat.completions.with_raw_response.create(
            model=MODEL, messages=[{"role": "user", "content": prompt}], max_tokens=5)
        print("call: OK, tokens used:", raw.parse().usage.total_tokens)
        show_limits(raw.headers)
    except APIStatusError as error:
        print("call failed:", error.status_code)
        print(" ", error.response.json().get("error", {}).get("message"))
        show_limits(error.response.headers)
    print("available models:")
    try:
        for model in client.models.list().data:
            print(" ", model.id)
    except Exception as error:
        print("  could not list:", type(error).__name__)


if __name__ == "__main__":
    main()
