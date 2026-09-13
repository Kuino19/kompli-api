with open(r'lib\features\auth\screens\passcode_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(260, min(len(lines), 323)):
    print(f"{i+1}: {lines[i]}", end="")
