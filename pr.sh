#!/usr/bin/env bash
set -euo pipefail
# Fetch PRs by an author and for each PR fetch reviews, comments, and reactions.
#
# Requirements:
# - gh (GitHub CLI)
# - jq
#
# Default behavior:
# - author: circleci-app[bot]
# - state: open
# - limit: 100
# - output: stdout (use --out to write to a file)
# - by default, also fetch reactions for each issue comment and review comment
#   (can be disabled with --skip-comment-reactions)
#
# Usage examples:
#   scripts/gh-fetch-circleci-bot-prs.sh
#   scripts/gh-fetch-circleci-bot-prs.sh --limit=50 --out=bot-prs.json
#   scripts/gh-fetch-circleci-bot-prs.sh --author=foo --state=open --limit=200
#   scripts/gh-fetch-circleci-bot-prs.sh --pr-url=https://github.com/owner/repo/pull/123
AUTHOR="circleci-app[bot]"
STATE="open"
LIMIT="100"
OUT=""
SKIP_COMMENT_REACTIONS="false"
PR_URL=""
for arg in "$@"; do
  case "$arg" in
    --author=*)
      AUTHOR="${arg#*=}"
      shift
      ;;
    --state=*)
      STATE="${arg#*=}"
      shift
      ;;
    --limit=*)
      LIMIT="${arg#*=}"
      shift
      ;;
    --out=*)
      OUT="${arg#*=}"
      shift
      ;;
    --skip-comment-reactions)
      SKIP_COMMENT_REACTIONS="true"
      shift
      ;;
    --pr-url=*)
      PR_URL="${arg#*=}"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--author=name] [--state=open|closed|merged] [--limit=N] [--out=path] [--skip-comment-reactions] [--pr-url=URL]" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required" >&2
  exit 1
fi
if [ -n "${PR_URL}" ]; then
  # Extract owner, repo, and PR number from URL
  # Expected format: https://github.com/owner/repo/pull/number
  if [[ ! "${PR_URL}" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)$ ]]; then
    echo "Error: PR URL must be in format https://github.com/owner/repo/pull/number" >&2
    exit 1
  fi
  
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
  
  echo "Fetching single PR: ${OWNER}/${REPO}#${NUMBER}" >&2
  
  # Fetch the single PR details
  PR_JSON=$(gh api "/repos/${OWNER}/${REPO}/pulls/${NUMBER}" --json number,html_url,title,user,created_at,updated_at,draft,labels,state 2>/dev/null)
  
  # Transform to match the expected format
  PR_STREAM=$(echo "${PR_JSON}" | jq -c '{
    number: .number,
    url: .html_url,
    owner: (.html_url | split("/")[3]),
    repo: (.html_url | split("/")[4]),
    title: .title,
    author: .user.login,
    createdAt: .created_at,
    updatedAt: .updated_at,
    state: .state,
    isDraft: .draft,
    labels: ((.labels // []) | map(.name))
  }')
else
  # Search PRs authored by AUTHOR, any repository, given state, limited by LIMIT
  # We derive owner/repo from the URL to support cross-repo results.
  echo "Searching PRs: author='${AUTHOR}', state='${STATE}', limit='${LIMIT}'" >&2
  PRS_JSON=$(gh search prs \
    --author="${AUTHOR}" \
    --state="${STATE}" \
    --limit="${LIMIT}" \
    --json number,url,title,author,createdAt,updatedAt,isDraft,labels,state 2>/dev/null)
  # Transform into a stream of minimal PR metadata with explicit owner and repo
  PR_STREAM=$(echo "${PRS_JSON}" | jq -c '
    [.[] | {
      number: .number,
      url: .url,
      owner: (.url | split("/")[3]),
      repo: (.url | split("/")[4]),
      title: .title,
      author: .author.login,
      createdAt: .createdAt,
      updatedAt: .updatedAt,
      state: .state,
      isDraft: .isDraft,
      labels: ((.labels // []) | map(.name))
    }] | .[]
  ')
fi
accept_header="application/vnd.github+json, application/vnd.github.squirrel-girl-preview+json"
aggregate_one_pr() {
  local pr_meta_json="$1"
  local number owner repo
  number=$(echo "${pr_meta_json}" | jq -r '.number')
  owner=$(echo "${pr_meta_json}" | jq -r '.owner')
  repo=$(echo "${pr_meta_json}" | jq -r '.repo')
  echo "Fetching details for ${owner}/${repo}#${number}" >&2
  # Issue comments (non-review comments on the PR thread)
  local issue_comments
  issue_comments=$(gh api -H "Accept: ${accept_header}" \
    "/repos/${owner}/${repo}/issues/${number}/comments?per_page=100" --paginate | jq -s 'add // []')
  # Review comments (comments on code diffs)
  local review_comments
  review_comments=$(gh api -H "Accept: ${accept_header}" \
    "/repos/${owner}/${repo}/pulls/${number}/comments?per_page=100" --paginate | jq -s 'add // []')
  # Reviews (approve/request changes/comment reviews)
  local reviews
  reviews=$(gh api -H "Accept: ${accept_header}" \
    "/repos/${owner}/${repo}/pulls/${number}/reviews?per_page=100" --paginate | jq -s 'add // []')
  # Reactions on the PR itself (PRs are issues under the hood)
  local pr_reactions
  pr_reactions=$(gh api -H "Accept: ${accept_header}" \
    "/repos/${owner}/${repo}/issues/${number}/reactions?per_page=100" --paginate | jq -s 'add // []')
  local commits
  commits=$(gh api -H "Accept: ${accept_header}" \
    "/repos/${owner}/${repo}/pulls/${number}/commits?per_page=100" --paginate | jq -s 'add // []')
  # Optionally fetch reactions for each issue comment and each review comment
  local issue_comments_with_reactions review_comments_with_reactions
  if [ "${SKIP_COMMENT_REACTIONS}" = "true" ]; then
    issue_comments_with_reactions="${issue_comments}"
    review_comments_with_reactions="${review_comments}"
  else
    # Map over each comment to fetch its reactions, preserving full comment object
    issue_comments_with_reactions=$(echo "${issue_comments}" | jq -c '.[]?' | while read -r c; do
      cid=$(echo "$c" | jq -r '.id')
      reactions=$(gh api -H "Accept: ${accept_header}" \
        "/repos/${owner}/${repo}/issues/comments/${cid}/reactions?per_page=100" --paginate | jq -s 'add // []')
      echo "$c" | jq --argjson reactions "${reactions}" '. + {reactions: $reactions}'
    done | jq -s 'map(.)')
    review_comments_with_reactions=$(echo "${review_comments}" | jq -c '.[]?' | while read -r c; do
      cid=$(echo "$c" | jq -r '.id')
      reactions=$(gh api -H "Accept: ${accept_header}" \
        "/repos/${owner}/${repo}/pulls/comments/${cid}/reactions?per_page=100" --paginate | jq -s 'add // []')
      echo "$c" | jq --argjson reactions "${reactions}" '. + {reactions: $reactions}'
    done | jq -s 'map(.)')
  fi
  # Combine
  jq -n \
    --argjson meta "${pr_meta_json}" \
    --argjson issueComments "${issue_comments_with_reactions}" \
    --argjson reviewComments "${review_comments_with_reactions}" \
    --argjson reviews "${reviews}" \
    --argjson prReactions "${pr_reactions}" \
    --argjson commits "${commits}" \
    '$meta + {
      issueComments: $issueComments,
      reviewComments: $reviewComments,
      reviews: $reviews,
      prReactions: $prReactions,
      commits: $commits
    }'
}
OUTPUT_TMP=$(mktemp)
trap 'rm -f "${OUTPUT_TMP}"' EXIT
while IFS= read -r pr; do
  aggregate_one_pr "${pr}"
done < <(printf "%s\n" "${PR_STREAM}") | jq -s '.' >"${OUTPUT_TMP}"
if [ -n "${OUT}" ]; then
  mv "${OUTPUT_TMP}" "${OUT}"
  echo "Wrote ${OUT}" >&2
  exit 0
fi
cat "${OUTPUT_TMP}"