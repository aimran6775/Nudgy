import requests, json

with open('/Users/abdullahimran/Desktop/untitled folder/Nudge/Secrets.xcconfig') as f:
    for line in f:
        if 'OPENAI_API_KEY' in line and '=' in line:
            api_key = line.split('=',1)[1].strip()
            break

# Chat test
resp = requests.post('https://api.openai.com/v1/chat/completions',
    headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
    json={'model': 'gpt-4o-mini', 'messages': [
        {'role': 'system', 'content': 'You are Nudgy, a cute penguin. Reply in 1 sentence.'},
        {'role': 'user', 'content': 'Hello!'}
    ], 'max_tokens': 50},
    timeout=10
)
print(f'Chat Status: {resp.status_code}')
if resp.status_code == 200:
    print(f'Chat Response: {resp.json()["choices"][0]["message"]["content"]}')
else:
    print(f'Chat Error: {resp.text[:200]}')

# TTS test
resp2 = requests.post('https://api.openai.com/v1/audio/speech',
    headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
    json={'model': 'tts-1', 'input': 'Hey, I am Nudgy!', 'voice': 'shimmer', 'response_format': 'mp3'},
    timeout=10
)
print(f'TTS Status: {resp2.status_code}, Size: {len(resp2.content)} bytes')
