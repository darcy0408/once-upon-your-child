git checkout main
git pull
git checkout -b docs/add-branch-workflow
# add BRANCH_WORKFLOW.md
git add BRANCH_WORKFLOW.md
git commit -m "docs: add branch workflow guide"
git push -u origin docs/add-branch-workflow
