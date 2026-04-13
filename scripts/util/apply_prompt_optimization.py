"""Apply optimized prompt to interactive_adventure_prompt_builder.py"""

# Read the optimized prompt template
with open('optimized_prompt_template.txt', 'r', encoding='utf-8') as f:
    new_prompt_section = f.read()

# Read the original file
with open('backend/services/interactive_adventure_prompt_builder.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Replace lines 138-307 inclusive (0-indexed: 137:307)
start_line = 137  # Lines[137] = line 138 in editor
end_line = 307    # Lines[307] = line 308 in editor (first line AFTER the prompt)

# Build new file: keep lines before 138, insert new prompt, keep lines from 308 onward
new_lines = lines[:start_line] + [new_prompt_section + '\n\n'] + lines[end_line:]

# Write back
with open('backend/services/interactive_adventure_prompt_builder.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"[OK] Replaced lines {start_line+1}-{end_line} ({end_line-start_line} lines)")
print(f"   Old size: {sum(len(line) for line in lines[start_line:end_line])} chars")
print(f"   New size: {len(new_prompt_section)} chars")
print(f"   Reduction: {100*(1 - len(new_prompt_section)/sum(len(line) for line in lines[start_line:end_line])):.1f}%")
