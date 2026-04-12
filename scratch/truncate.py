import sys

path = r"d:\3d design\ElderCareAI\backend\services\analysis_service.py"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Keep only the first 563 lines
lines = lines[:563]

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("Truncated file successfully.")
