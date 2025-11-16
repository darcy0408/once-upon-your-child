#!/usr/bin/env python3
"""
AI-Powered Performance Optimization Assistant
Automated code analysis and optimization recommendations for Story Weaver
"""

import os
import re
import ast
import json
import logging
from typing import Dict, List, Any, Optional, Tuple
from pathlib import Path
import requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PerformanceOptimizer:
    def __init__(self):
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        self.project_root = Path("/app")  # Adjust for actual deployment path

        # Performance patterns to detect
        self.performance_patterns = {
            'n_plus_one_queries': re.compile(r'\.all\(\)|\.filter\(.*\)\.all\(\)'),
            'inefficient_loops': re.compile(r'for.*in.*\.all\(\)'),
            'memory_leaks': re.compile(r'global.*=|self\.\w+\s*=.*\[\]'),
            'blocking_operations': re.compile(r'requests\.(get|post|put|delete)\('),
            'large_objects': re.compile(r'load.*\*|select.*\*'),
            'cache_misses': re.compile(r'cache\.get.*None|redis\.get.*None'),
        }

        # Optimization recommendations database
        self.optimization_db = self._load_optimization_database()

    def _load_optimization_database(self) -> Dict[str, Any]:
        """Load database of known optimizations"""
        return {
            'database_optimizations': {
                'n_plus_one': {
                    'pattern': 'N+1 query detected',
                    'solution': 'Use select_related() or prefetch_related() for related objects',
                    'code_example': 'Model.objects.select_related(\'foreign_key\').all()',
                    'impact': 'high',
                    'effort': 'medium'
                },
                'missing_indexes': {
                    'pattern': 'Slow query on unindexed field',
                    'solution': 'Add database index on frequently queried fields',
                    'code_example': 'CREATE INDEX idx_field ON table(field);',
                    'impact': 'high',
                    'effort': 'low'
                },
                'large_result_sets': {
                    'pattern': 'Loading large datasets into memory',
                    'solution': 'Use pagination or streaming for large queries',
                    'code_example': 'Model.objects.all()[:100] or use iterator()',
                    'impact': 'high',
                    'effort': 'medium'
                }
            },
            'cache_optimizations': {
                'cache_misses': {
                    'pattern': 'High cache miss rate',
                    'solution': 'Increase cache TTL or implement cache warming',
                    'code_example': 'cache.set(key, value, timeout=3600)',
                    'impact': 'medium',
                    'effort': 'low'
                },
                'inefficient_keys': {
                    'pattern': 'Complex cache keys',
                    'solution': 'Simplify cache keys and use consistent naming',
                    'code_example': 'cache_key = f"user:{user_id}:profile"',
                    'impact': 'low',
                    'effort': 'low'
                }
            },
            'memory_optimizations': {
                'large_objects': {
                    'pattern': 'Loading unnecessary data',
                    'solution': 'Use defer() or only() to load specific fields',
                    'code_example': 'Model.objects.defer(\'large_field\').get()',
                    'impact': 'medium',
                    'effort': 'low'
                },
                'memory_leaks': {
                    'pattern': 'Potential memory leak',
                    'solution': 'Use weak references or proper cleanup',
                    'code_example': 'import weakref; obj = weakref.ref(object)',
                    'impact': 'high',
                    'effort': 'high'
                }
            },
            'api_optimizations': {
                'blocking_calls': {
                    'pattern': 'Blocking HTTP calls',
                    'solution': 'Use async/await or background tasks',
                    'code_example': 'async def api_call(): return await httpx.get(url)',
                    'impact': 'high',
                    'effort': 'medium'
                },
                'no_compression': {
                    'pattern': 'Uncompressed responses',
                    'solution': 'Enable gzip/brotli compression',
                    'code_example': '@app.after_request\ndef add_compression(response):',
                    'impact': 'medium',
                    'effort': 'low'
                }
            }
        }

    def analyze_codebase(self) -> Dict[str, Any]:
        """Analyze the entire codebase for performance issues"""
        analysis_results = {
            'timestamp': datetime.utcnow().isoformat(),
            'files_analyzed': 0,
            'issues_found': [],
            'recommendations': [],
            'performance_score': 0,
            'critical_issues': 0,
            'high_impact_opportunities': 0
        }

        # Analyze Python files
        python_files = list(self.project_root.rglob("*.py"))
        for file_path in python_files:
            if self._should_analyze_file(file_path):
                file_issues = self.analyze_file(file_path)
                analysis_results['issues_found'].extend(file_issues)
                analysis_results['files_analyzed'] += 1

        # Analyze Flutter/Dart files
        dart_files = list(self.project_root.rglob("*.dart"))
        for file_path in dart_files:
            if self._should_analyze_file(file_path):
                file_issues = self.analyze_dart_file(file_path)
                analysis_results['issues_found'].extend(file_issues)
                analysis_results['files_analyzed'] += 1

        # Generate recommendations
        analysis_results['recommendations'] = self._generate_recommendations(analysis_results['issues_found'])

        # Calculate performance score
        analysis_results['performance_score'] = self._calculate_performance_score(analysis_results)
        analysis_results['critical_issues'] = len([i for i in analysis_results['issues_found'] if i['severity'] == 'critical'])
        analysis_results['high_impact_opportunities'] = len([i for i in analysis_results['issues_found'] if i['impact'] == 'high'])

        return analysis_results

    def _should_analyze_file(self, file_path: Path) -> bool:
        """Determine if a file should be analyzed"""
        # Skip common exclude patterns
        exclude_patterns = [
            '__pycache__',
            'node_modules',
            '.git',
            'migrations',
            'tests',
            'venv',
            'env'
        ]

        for pattern in exclude_patterns:
            if pattern in str(file_path):
                return False

        # Only analyze source files
        if file_path.suffix in ['.py', '.dart']:
            return True

        return False

    def analyze_file(self, file_path: Path) -> List[Dict[str, Any]]:
        """Analyze a Python file for performance issues"""
        issues = []

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Check for performance patterns
            for pattern_name, pattern in self.performance_patterns.items():
                matches = pattern.findall(content)
                if matches:
                    issues.append({
                        'file': str(file_path.relative_to(self.project_root)),
                        'line': self._find_line_number(content, matches[0]),
                        'type': pattern_name,
                        'severity': self._get_pattern_severity(pattern_name),
                        'description': f"Detected {pattern_name.replace('_', ' ')}",
                        'code_snippet': matches[0][:100] + '...' if len(matches[0]) > 100 else matches[0],
                        'impact': self._get_pattern_impact(pattern_name),
                        'recommendation': self._get_pattern_recommendation(pattern_name)
                    })

            # Check for complex functions
            issues.extend(self._analyze_function_complexity(content, file_path))

        except Exception as e:
            logger.error(f"Error analyzing {file_path}: {e}")

        return issues

    def analyze_dart_file(self, file_path: Path) -> List[Dict[str, Any]]:
        """Analyze a Dart file for performance issues"""
        issues = []

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Check for common Flutter performance issues
            flutter_patterns = {
                'rebuild_everything': re.compile(r'setState\(\(\)'),
                'large_lists': re.compile(r'ListView\.builder.*itemCount.*>.*100'),
                'expensive_builds': re.compile(r'build.*\{[^}]*[^}]*\}'),
                'memory_leaks': re.compile(r'Disposable.*dispose|Stream.*listen.*cancel'),
            }

            for pattern_name, pattern in flutter_patterns.items():
                matches = pattern.findall(content)
                if matches:
                    issues.append({
                        'file': str(file_path.relative_to(self.project_root)),
                        'line': self._find_line_number(content, matches[0]),
                        'type': f"flutter_{pattern_name}",
                        'severity': 'medium',
                        'description': f"Flutter performance issue: {pattern_name.replace('_', ' ')}",
                        'code_snippet': matches[0][:100] + '...' if len(matches[0]) > 100 else matches[0],
                        'impact': 'medium',
                        'recommendation': self._get_flutter_recommendation(pattern_name)
                    })

        except Exception as e:
            logger.error(f"Error analyzing Dart file {file_path}: {e}")

        return issues

    def _analyze_function_complexity(self, content: str, file_path: Path) -> List[Dict[str, Any]]:
        """Analyze function complexity"""
        issues = []

        try:
            tree = ast.parse(content)

            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef):
                    # Count lines in function
                    if hasattr(node, 'end_lineno') and hasattr(node, 'lineno'):
                        line_count = node.end_lineno - node.lineno
                        if line_count > 50:  # Function too long
                            issues.append({
                                'file': str(file_path.relative_to(self.project_root)),
                                'line': node.lineno,
                                'type': 'complex_function',
                                'severity': 'low',
                                'description': f"Function '{node.name}' is too long ({line_count} lines)",
                                'code_snippet': f"def {node.name}(...",
                                'impact': 'low',
                                'recommendation': 'Consider breaking down into smaller functions'
                            })

        except SyntaxError:
            # Skip files with syntax errors
            pass

        return issues

    def _find_line_number(self, content: str, match: str) -> int:
        """Find the line number of a match in content"""
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            if match in line:
                return i
        return 0

    def _get_pattern_severity(self, pattern_name: str) -> str:
        """Get severity level for a pattern"""
        severity_map = {
            'n_plus_one_queries': 'high',
            'blocking_operations': 'high',
            'memory_leaks': 'critical',
            'large_objects': 'medium',
            'inefficient_loops': 'medium',
            'cache_misses': 'low'
        }
        return severity_map.get(pattern_name, 'low')

    def _get_pattern_impact(self, pattern_name: str) -> str:
        """Get impact level for a pattern"""
        impact_map = {
            'n_plus_one_queries': 'high',
            'blocking_operations': 'high',
            'memory_leaks': 'critical',
            'large_objects': 'medium',
            'inefficient_loops': 'medium',
            'cache_misses': 'low'
        }
        return impact_map.get(pattern_name, 'low')

    def _get_pattern_recommendation(self, pattern_name: str) -> str:
        """Get recommendation for a pattern"""
        recommendations = {
            'n_plus_one_queries': 'Use select_related() or prefetch_related() to optimize database queries',
            'blocking_operations': 'Move to background tasks or use async operations',
            'memory_leaks': 'Implement proper cleanup and use weak references where appropriate',
            'large_objects': 'Use pagination or selective field loading',
            'inefficient_loops': 'Optimize loop logic or use list comprehensions',
            'cache_misses': 'Increase cache TTL or implement cache warming strategies'
        }
        return recommendations.get(pattern_name, 'Review and optimize this code pattern')

    def _get_flutter_recommendation(self, pattern_name: str) -> str:
        """Get Flutter-specific recommendations"""
        recommendations = {
            'rebuild_everything': 'Use const widgets and keys to prevent unnecessary rebuilds',
            'large_lists': 'Implement virtualization with ListView.builder and proper itemExtent',
            'expensive_builds': 'Extract expensive operations to initState or use FutureBuilder',
            'memory_leaks': 'Ensure proper disposal of controllers and cancellation of subscriptions'
        }
        return recommendations.get(pattern_name, 'Review Flutter performance best practices')

    def _generate_recommendations(self, issues: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate prioritized recommendations from issues"""
        recommendations = []

        # Group issues by type
        issue_groups = {}
        for issue in issues:
            issue_type = issue['type']
            if issue_type not in issue_groups:
                issue_groups[issue_type] = []
            issue_groups[issue_type].append(issue)

        # Generate recommendations for each group
        for issue_type, group_issues in issue_groups.items():
            if issue_type in self.optimization_db:
                db_entry = self.optimization_db[issue_type]
                recommendations.append({
                    'type': issue_type,
                    'count': len(group_issues),
                    'description': db_entry.get('pattern', issue_type),
                    'solution': db_entry.get('solution', 'Review and optimize'),
                    'code_example': db_entry.get('code_example', ''),
                    'impact': db_entry.get('impact', 'medium'),
                    'effort': db_entry.get('effort', 'medium'),
                    'affected_files': [issue['file'] for issue in group_issues[:5]]  # Show first 5
                })

        # Sort by impact and count
        recommendations.sort(key=lambda x: (self._impact_score(x['impact']), x['count']), reverse=True)

        return recommendations

    def _impact_score(self, impact: str) -> int:
        """Convert impact to numeric score"""
        scores = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1}
        return scores.get(impact, 1)

    def _calculate_performance_score(self, analysis_results: Dict[str, Any]) -> float:
        """Calculate overall performance score (0-100)"""
        issues = analysis_results['issues_found']

        if not issues:
            return 100.0

        # Weight issues by severity and impact
        total_weight = 0
        for issue in issues:
            severity_weight = {'critical': 10, 'high': 5, 'medium': 2, 'low': 1}
            impact_weight = {'critical': 10, 'high': 5, 'medium': 2, 'low': 1}

            weight = severity_weight.get(issue['severity'], 1) * impact_weight.get(issue['impact'], 1)
            total_weight += weight

        # Convert to score (higher issues = lower score)
        # Max reasonable weight = 1000, min score = 0
        score = max(0, 100 - (total_weight / 10))
        return round(score, 1)

    def get_ai_optimization_suggestions(self, analysis_results: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Use AI to generate advanced optimization suggestions"""
        if not self.openai_api_key:
            return []

        try:
            # Prepare analysis summary for AI
            summary = {
                'performance_score': analysis_results['performance_score'],
                'critical_issues': analysis_results['critical_issues'],
                'high_impact_opportunities': analysis_results['high_impact_opportunities'],
                'top_issues': analysis_results['issues_found'][:10],  # Top 10 issues
                'recommendations': analysis_results['recommendations'][:5]  # Top 5 recommendations
            }

            prompt = f"""
Analyze this performance analysis and provide advanced optimization suggestions:

Performance Score: {summary['performance_score']}/100
Critical Issues: {summary['critical_issues']}
High Impact Opportunities: {summary['high_impact_opportunities']}

Top Issues:
{json.dumps(summary['top_issues'][:3], indent=2)}

Current Recommendations:
{json.dumps(summary['recommendations'][:3], indent=2)}

Provide 3-5 advanced optimization suggestions that go beyond the basic recommendations.
Focus on architectural improvements, advanced caching strategies, or system-level optimizations.
"""

            response = requests.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.openai_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 800
                }
            )

            if response.status_code == 200:
                result = response.json()
                ai_suggestions = result['choices'][0]['message']['content']

                # Parse AI suggestions into structured format
                return self._parse_ai_suggestions(ai_suggestions)

        except Exception as e:
            logger.error(f"AI optimization suggestions failed: {e}")

        return []

    def _parse_ai_suggestions(self, ai_text: str) -> List[Dict[str, Any]]:
        """Parse AI-generated suggestions into structured format"""
        suggestions = []

        # Simple parsing - split by numbered items
        lines = ai_text.split('\n')
        current_suggestion = None

        for line in lines:
            line = line.strip()
            if re.match(r'^\d+\.', line):  # Numbered item
                if current_suggestion:
                    suggestions.append(current_suggestion)

                current_suggestion = {
                    'title': line.split('.', 1)[1].strip(),
                    'description': '',
                    'impact': 'medium',
                    'effort': 'medium',
                    'source': 'ai_generated'
                }
            elif current_suggestion and line:
                current_suggestion['description'] += line + ' '

        if current_suggestion:
            suggestions.append(current_suggestion)

        return suggestions

    def generate_optimization_report(self) -> Dict[str, Any]:
        """Generate comprehensive optimization report"""
        logger.info("Starting comprehensive performance analysis...")

        # Analyze codebase
        analysis_results = self.analyze_codebase()

        # Get AI suggestions
        ai_suggestions = self.get_ai_optimization_suggestions(analysis_results)

        # Combine results
        report = {
            **analysis_results,
            'ai_suggestions': ai_suggestions,
            'optimization_plan': self._create_optimization_plan(analysis_results, ai_suggestions),
            'estimated_improvement': self._estimate_improvement(analysis_results),
            'implementation_priority': self._prioritize_implementation(analysis_results['recommendations'])
        }

        return report

    def _create_optimization_plan(self, analysis: Dict[str, Any], ai_suggestions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create a phased optimization plan"""
        plan = []

        # Phase 1: Critical fixes
        critical_items = [r for r in analysis['recommendations'] if r['impact'] == 'critical']
        if critical_items:
            plan.append({
                'phase': 1,
                'name': 'Critical Performance Fixes',
                'duration': '1-2 days',
                'items': critical_items,
                'focus': 'Fix memory leaks, blocking operations, and critical bottlenecks'
            })

        # Phase 2: High impact optimizations
        high_items = [r for r in analysis['recommendations'] if r['impact'] == 'high']
        if high_items:
            plan.append({
                'phase': 2,
                'name': 'High Impact Optimizations',
                'duration': '3-5 days',
                'items': high_items,
                'focus': 'Database optimizations, caching improvements, and API enhancements'
            })

        # Phase 3: Advanced improvements
        advanced_items = ai_suggestions + [r for r in analysis['recommendations'] if r['impact'] in ['medium', 'low']]
        if advanced_items:
            plan.append({
                'phase': 3,
                'name': 'Advanced Optimizations',
                'duration': '1-2 weeks',
                'items': advanced_items[:10],  # Top 10
                'focus': 'Architectural improvements and advanced caching strategies'
            })

        return plan

    def _estimate_improvement(self, analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Estimate performance improvement potential"""
        current_score = analysis['performance_score']
        critical_count = analysis['critical_issues']
        high_count = analysis['high_impact_opportunities']

        # Estimate improvement based on issues
        estimated_gain = min(30, critical_count * 5 + high_count * 3)
        target_score = min(100, current_score + estimated_gain)

        return {
            'current_score': current_score,
            'estimated_improvement': estimated_gain,
            'target_score': target_score,
            'confidence': 'medium',
            'timeframe': '2-4 weeks with proper implementation'
        }

    def _prioritize_implementation(self, recommendations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Create implementation priority list"""
        prioritized = []

        for rec in recommendations:
            priority_score = (
                self._impact_score(rec['impact']) * 2 +
                (5 - self._effort_score(rec.get('effort', 'medium')))  # Lower effort = higher priority
            )

            prioritized.append({
                **rec,
                'priority_score': priority_score,
                'implementation_order': len(prioritized) + 1
            })

        # Sort by priority score
        prioritized.sort(key=lambda x: x['priority_score'], reverse=True)

        return prioritized

    def _effort_score(self, effort: str) -> int:
        """Convert effort to numeric score"""
        scores = {'low': 1, 'medium': 2, 'high': 3}
        return scores.get(effort, 2)

def main():
    """Main performance optimization execution"""
    try:
        optimizer = PerformanceOptimizer()
        report = optimizer.generate_optimization_report()

        print("=== AI Performance Optimization Report ===")
        print(f"Performance Score: {report['performance_score']}/100")
        print(f"Files Analyzed: {report['files_analyzed']}")
        print(f"Issues Found: {len(report['issues_found'])}")
        print(f"Critical Issues: {report['critical_issues']}")
        print(f"High Impact Opportunities: {report['high_impact_opportunities']}")
        print(f"AI Suggestions: {len(report['ai_suggestions'])}")

        if report['optimization_plan']:
            print(f"\nOptimization Plan: {len(report['optimization_plan'])} phases")
            for phase in report['optimization_plan'][:2]:  # Show first 2 phases
                print(f"  Phase {phase['phase']}: {phase['name']} ({phase['duration']})")
                print(f"    Focus: {phase['focus']}")
                print(f"    Items: {len(phase['items'])}")

        improvement = report['estimated_improvement']
        print(f"\nEstimated Improvement: +{improvement['estimated_improvement']} points")
        print(f"Target Score: {improvement['target_score']}/100")
        print(f"Timeframe: {improvement['timeframe']}")

        # Save detailed report
        with open('/tmp/performance_report.json', 'w') as f:
            json.dump(report, f, indent=2, default=str)

        print("\nDetailed report saved to /tmp/performance_report.json")

        return 0

    except Exception as e:
        logger.error(f"Performance optimization failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())