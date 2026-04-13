"""Apply optimized continuation prompt"""

# Read the optimized prompt template
with open('optimized_continuation_prompt.txt', 'r', encoding='utf-8') as f:
    new_prompt_section = f.read()

# Read the original file
with open('backend/services/interactive_adventure_prompt_builder.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the continuation prompt bounds
start_line = None
end_line = None

for i, line in enumerate(lines):
    if 'prompt = f"""# Continue Interactive Adventure' in line:
        start_line = i
    if start_line and i > start_line and 'Generate the next segment as valid JSON."""' in line:
        end_line = i + 1  # Include this line
        break

if not start_line or not end_line:
    print("[ERROR] Could not find continuation prompt bounds")
    exit(1)

# Build new file
new_lines = lines[:start_line] + [new_prompt_section + '\n\n'] + lines[end_line:]

# Write back
with open('backend/services/interactive_adventure_prompt_builder.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"[OK] Replaced lines {start_line+1}-{end_line} ({end_line-start_line} lines)")
print(f"   Old size: {sum(len(line) for line in lines[start_line:end_line])} chars")
print(f"   New size: {len(new_prompt_section)} chars")
print(f"   Reduction: {100*(1 - len(new_prompt_section)/sum(len(line) for line in lines[start_line:end_line])):.1f}%")
