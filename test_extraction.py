#!/usr/bin/env python3
"""Test the Nudge brain dump extraction pipeline against OpenAI API."""

import json
import urllib.request

import os
API_KEY = os.environ.get("OPENAI_API_KEY", "")

SYSTEM_PROMPT = """You are an expert task extractor for an ADHD-friendly app. The user spoke a messy, unstructured brain dump.
Your job: parse it into clean, actionable task cards with rich metadata.

Today's date: 2026-02-08, Sunday

Respond with ONLY valid JSON (no markdown, no backticks). Format:
{"tasks": [{"content": "...", "emoji": "...", "actionType": "...", "contactName": "...", "actionTarget": "", "isActionable": true, "priority": "...", "dueDateString": "..."}]}

FIELD RULES:
- content: Short, clear, actionable task (max 8 words). Start with a verb. Strip filler.
- emoji: One relevant emoji. Use context: 📞 for calls, ✉️ for email, 🏥 for medical, 💰 for money, 🛒 for shopping, etc.
- actionType: "CALL" / "TEXT" / "EMAIL" or "" — detect from verbs like call, ring, text, message, email, send.
- contactName: Person or business name if mentioned, "" otherwise.
- actionTarget: Only if an explicit phone/email/URL was spoken. Usually "".
- priority: Infer from urgency cues:
  - "high": urgent, overdue, deadline, ASAP, critical, "really need to", "have to before", "can't forget"
  - "medium": normal tasks, no urgency signals
  - "low": "maybe", "when I get a chance", "at some point", "not urgent"
- dueDateString: Extract time references as YYYY-MM-DD when possible. Use relative words verbatim otherwise:
  - "call dentist tomorrow" → "tomorrow"
  - "pay rent by the 5th" → YYYY-MM-05 (current or next month)
  - "this weekend" → "this weekend"
  - "before Friday" → YYYY-MM-DD of this Friday
  - No time mentioned → ""

EXTRACTION RULES:
1. Ignore filler: um, uh, like, you know, I mean, so yeah, anyway
2. Skip non-actionable venting: "I'm so tired", "this sucks" → not tasks
3. Split compound tasks: "call mom and pick up groceries" → TWO separate tasks
4. Preserve specificity: "buy milk" not "go shopping"
5. Cap at 10 tasks. Merge duplicates.
6. Order by priority (high first, low last)"""


TEST_CASES = [
    {
        "name": "Test 1: Classic messy brain dump",
        "input": "ok so I woke up late again and I really need to um call my doctor to reschedule that appointment, and oh yeah I have to submit the project report by Tuesday or my boss is gonna kill me, also I should probably text mom happy birthday I keep forgetting, and like I need groceries we have no food, maybe pick up that dry cleaning at some point, and I gotta pay the electric bill before they shut it off, oh and I want to look into signing up for that yoga class Sarah told me about"
    },
    {
        "name": "Test 2: Short quick list",
        "input": "buy milk, call dentist tomorrow, text Sarah about dinner tonight"
    },
    {
        "name": "Test 3: Lots of filler and venting",
        "input": "ugh I'm so stressed out lately, like everything is falling apart, anyway I guess I should probably pay rent it's due on the 5th, and um oh yeah I need to email professor Johnson about the extension on my paper, it's so unfair that he only gave us a week, whatever, and I should get gas for the car, oh and my mom keeps asking me to call her back, I just can't deal right now but I should"
    },
    {
        "name": "Test 4: Compound tasks with contacts",
        "input": "I need to call the bank and also text Jake about picking up his stuff from my place on Saturday, and email my landlord about the broken sink, and maybe sometime this week go to the gym"
    },
]


def test_extraction(test_case):
    body = json.dumps({
        "model": "gpt-4o-mini",
        "temperature": 0.3,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f'Extract tasks from this brain dump:\n"{test_case["input"]}"'}
        ]
    }).encode()

    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    )

    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    content = result["choices"][0]["message"]["content"]
    
    # Clean markdown if present
    content = content.replace("```json", "").replace("```", "").strip()
    tasks = json.loads(content)

    print(f"\n{'='*60}")
    print(f"📋 {test_case['name']}")
    print(f"   Input: \"{test_case['input'][:80]}...\"")
    print(f"   → {len(tasks['tasks'])} tasks extracted")
    print(f"{'='*60}")
    
    for i, t in enumerate(tasks["tasks"], 1):
        priority = t.get("priority", "medium").upper()
        emoji = t.get("emoji", "📝")
        content_text = t.get("content", "")
        due = t.get("dueDateString", "")
        action = t.get("actionType", "")
        contact = t.get("contactName", "")
        
        # Color-code priority
        if priority == "HIGH":
            p_marker = "🔴"
        elif priority == "MEDIUM":
            p_marker = "🔵"
        else:
            p_marker = "⚪"
        
        due_str = f" 📅 {due}" if due else ""
        action_str = f" [{action} → {contact}]" if action else (f" 👤 {contact}" if contact else "")
        print(f"  {p_marker} [{i}] {emoji} {content_text}{due_str}{action_str}")
    
    return tasks


if __name__ == "__main__":
    print("\n🧠 NUDGE BRAIN DUMP EXTRACTION PIPELINE TEST")
    print("=" * 60)
    print(f"Model: gpt-4o-mini | Temperature: 0.3")
    print(f"Date context: 2026-02-08, Sunday")
    
    all_tasks = []
    for tc in TEST_CASES:
        try:
            result = test_extraction(tc)
            all_tasks.append(result)
        except Exception as e:
            print(f"\n❌ {tc['name']} FAILED: {e}")
    
    # Summary
    total = sum(len(r["tasks"]) for r in all_tasks)
    print(f"\n{'='*60}")
    print(f"✅ ALL {len(TEST_CASES)} TESTS COMPLETE — {total} total tasks extracted")
    
    # Check quality metrics
    all_flat = [t for r in all_tasks for t in r["tasks"]]
    priorities = [t.get("priority", "medium") for t in all_flat]
    with_dates = [t for t in all_flat if t.get("dueDateString", "")]
    with_actions = [t for t in all_flat if t.get("actionType", "")]
    with_contacts = [t for t in all_flat if t.get("contactName", "")]
    
    print(f"   Priority breakdown: {priorities.count('high')} high, {priorities.count('medium')} medium, {priorities.count('low')} low")
    print(f"   With due dates: {len(with_dates)}/{total}")
    print(f"   With actions: {len(with_actions)}/{total} (CALL/TEXT/EMAIL)")
    print(f"   With contacts: {len(with_contacts)}/{total}")
    print(f"{'='*60}")
