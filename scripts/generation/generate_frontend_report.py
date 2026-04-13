import os
import re
from collections import defaultdict

def parse_lcov(file_path):
    coverage_data = defaultdict(lambda: {'total': 0, 'covered': 0})
    current_file = None
    
    with open(file_path, 'r') as f:
        for line in f:
            if line.startswith('SF:'):
                current_file = line.strip().split(':')[1]
                # Normalize path
                try:
                    current_file = os.path.relpath(current_file, os.getcwd())
                except:
                    pass
            elif line.startswith('LF:'):
                coverage_data[current_file]['total'] = int(line.strip().split(':')[1])
            elif line.startswith('LH:'):
                coverage_data[current_file]['covered'] = int(line.strip().split(':')[1])
                
    return coverage_data

def summarize_by_dir(coverage_data):
    dir_summary = defaultdict(lambda: {'total': 0, 'covered': 0})
    
    for file_path, data in coverage_data.items():
        # Get top level directory or root
        parts = file_path.split(os.sep)
        if len(parts) > 1:
            dir_name = parts[0]
            if dir_name == 'lib':
                if len(parts) > 2:
                    dir_name = os.path.join('lib', parts[1])
                else:
                    dir_name = 'lib'
        else:
            dir_name = '.'
            
        dir_summary[dir_name]['total'] += data['total']
        dir_summary[dir_name]['covered'] += data['covered']
        
    return dir_summary

def main():
    lcov_path = os.path.join('coverage', 'lcov.info')
    if not os.path.exists(lcov_path):
        print("lcov.info not found")
        return
        
    data = parse_lcov(lcov_path)
    summary = summarize_by_dir(data)
    
    print("# Frontend Test Coverage Report")
    print("**Date:** 2026-02-13")
    
    total_lines = sum(d['total'] for d in summary.values())
    covered_lines = sum(d['covered'] for d in summary.values())
    overall_percent = (covered_lines / total_lines * 100) if total_lines > 0 else 0
    
    print(f"**Overall Coverage:** {overall_percent:.1f}%")
    print("\n## Coverage Summary by Module\n")
    print("| Module | Lines | Covered | Coverage |")
    print("|--------|-------|---------|----------|")
    
    sorted_modules = sorted(summary.items())
    for module, stats in sorted_modules:
        pct = (stats['covered'] / stats['total'] * 100) if stats['total'] > 0 else 0
        print(f"| `{module}` | {stats['total']} | {stats['covered']} | {pct:.1f}% |")
        
    print(f"| **TOTAL** | **{total_lines}** | **{covered_lines}** | **{overall_percent:.1f}%** |")

if __name__ == "__main__":
    main()
