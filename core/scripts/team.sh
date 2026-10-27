#!/usr/bin/env bash
# team.sh - read-only team registry lookup for .agents/team.yml
set -e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REG="$ROOT/.agents/team.yml"

usage() { echo "Usage: team.sh <command> [args]" >&2; exit 2; }
die() { echo "team.sh: $*" >&2; exit "$2"; }
need_reg() { [ -f "$REG" ] || die "missing .agents/team.yml" 4; }
normalize_path() { local p="$1"; p="${p#./}"; p="${p%/}"; [ -z "$p" ] && p="."; printf '%s\n' "$p"; }

parse_registry() {
  need_reg
  awk '
    BEGIN { in_fm=0; section=""; item_id=0; current_item=0; in_ids=0; in_git_block=0; }
    NR==1 && $0 ~ /^---[ \t]*$/ { in_fm=1; next }
    NR==1 { in_fm=1 }
    in_fm && $0 ~ /^---[ \t]*$/ { in_fm=0; next }
    in_fm==0 { next }
    /^[ \t]*#/ { next }
    /^[ \t]*$/ { if(in_git_block) in_git_block=0; next }
    /^[ \t]*members:[ \t]*$/ { section="members"; in_ids=0; next }
    /^[ \t]*contacts:[ \t]*$/ { section="contacts"; in_ids=0; next }
    /^[ \t]*assignee_by_workspace:[ \t]*$/ { section="assignee"; in_ids=0; next }
    /^[ \t]*-[ \t]*key:[ \t]*/ {
      item_id++; current_item=item_id
      s=$0; sub(/^[ \t]*-[ \t]*key:[ \t]*/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/["\047]/, "", s)
      printf "ITEM\t%d\t%s\t%s\n", current_item, section, s
      in_ids=0; in_git_block=0; next
    }
    /^[ \t]+name:[ \t]*/ {
      if(current_item==0) next
      s=$0; sub(/^[ \t]+name:[ \t]*/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^["\047]|["\047]$/, "", s)
      printf "NAME\t%d\t%s\n", current_item, s
      in_ids=0; next
    }
    /^[ \t]+role:[ \t]*/ {
      if(current_item==0) next
      s=$0; sub(/^[ \t]+role:[ \t]*/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^["\047]|["\047]$/, "", s)
      printf "ROLE\t%d\t%s\n", current_item, s
      in_ids=0; next
    }
    /^[ \t]+title:[ \t]*/ {
      if(current_item==0) next
      s=$0; sub(/^[ \t]+title:[ \t]*/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^["\047]|["\047]$/, "", s)
      printf "TITLE\t%d\t%s\n", current_item, s
      in_ids=0; next
    }
    /^[ \t]+ids:[ \t]*$/ { in_ids=1; in_git_block=0; next }
    in_ids && /^[ \t]+[a-zA-Z0-9_-]+:[ \t]*\[/ {
      line=$0; sub(/^[ \t]+/, "", line); idx=index(line,":"); p=substr(line,1,idx-1); gsub(/^[ \t]+|[ \t]+$/, "", p)
      sub(/^[^[]*\[/, "", line); sub(/\].*/, "", line); m=split(line,arr,",")
      for(i=1;i<=m;i++){ gsub(/^[ \t]+|[ \t]+$/, "", arr[i]); gsub(/^["\047]|["\047]$/, "", arr[i]); if(arr[i]!="") printf "ID\t%d\t%s\t%s\n", current_item,p,arr[i] }
      in_git_block=0; next
    }
    in_ids && /^[ \t]+git:[ \t]*$/ { in_git_block=1; next }
    in_git_block && /^[ \t]+-[ \t]*/ {
      s=$0; sub(/^[ \t]+-[ \t]*/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^["\047]|["\047]$/, "", s)
      if(s!="") printf "ID\t%d\tgit\t%s\n", current_item,s
      next
    }
    in_ids && /^[ \t]+[a-zA-Z0-9_-]+:[ \t]+/ && $0 !~ /\[/ {
      line=$0; sub(/^[ \t]+/, "", line); idx=index(line,":"); p=substr(line,1,idx-1); gsub(/^[ \t]+|[ \t]+$/, "", p)
      if(p=="git"){ in_git_block=0; next }
      rest=line; sub(/^[^:]+:[ \t]*/, "", rest); gsub(/^[ \t]+|[ \t]+$/, "", rest); gsub(/^["\047]|["\047]$/, "", rest)
      if(rest!="") printf "ID\t%d\t%s\t%s\n", current_item,p,rest
      in_git_block=0; next
    }
    section=="assignee" && /^[ \t]*[a-zA-Z0-9_.\/*-]+:[ \t]*\[/ {
      line=$0; idx=index(line,":"); w=substr(line,1,idx-1); gsub(/^[ \t]+|[ \t]+$/, "", w)
      sub(/^[^[]*\[/, "", line); sub(/\].*/, "", line); printf "ASGN\t%s\t%s\n", w,line; next
    }
    section=="assignee" && /^[ \t]*\.[ \t]*:[ \t]*\[/ {
      line=$0; sub(/^[^[]*\[/, "", line); sub(/\].*/, "", line); printf "ASGN\t%s\t%s\n", ".", line; next
    }
  ' "$REG"
}

cmd_whoami() {
  need_reg
  local email="" json=0
  while [ $# -gt 0 ]; do case "$1" in --email) email="$2"; shift 2;; --json) json=1; shift;; *) shift;; esac; done
  [ -n "$email" ] || email="$(git -C "$ROOT" config user.email 2>/dev/null || true)"
  [ -n "$email" ] || die "no git email" 3
  local eml
  eml="$(printf '%s' "$email" | tr '[:upper:]' '[:lower:]')"
  local data res
  data="$(parse_registry)"
  res="$(awk -F'\t' -v e="$eml" '
    $1=="ITEM"{id=$2+0; kind=$3; key=$4}
    $1=="NAME" && ($2+0)==id {name=$3; hasname=1}
    $1=="ID" && ($2+0)==id && tolower($3)=="git" {
      g=tolower($4)
      if(g==e){ if(hasname && name!="") printf "%s\t%s\t%s\n", key,name,kind; else printf "%s\t\t%s\n", key,kind; found=1 }
    }
    END{if(!found) exit 3; else exit 0}
  ' <<< "$data")"
  local rc=$?
  [ $rc -ne 0 ] && exit 3
  [ -z "$res" ] && exit 3
  if [ $json -eq 1 ]; then awk -F'\t' '{printf "{\"key\":\"%s\",\"name\":\"%s\",\"kind\":\"%s\"}\n",$1,$2,$3}' <<< "$res" | head -1
  else echo "$res" | head -1; fi
}

cmd_match() {
  need_reg
  [ $# -ge 2 ] || usage
  local plat="$1" id="$2" json=0; shift 2
  while [ $# -gt 0 ]; do case "$1" in --json) json=1; shift;; *) shift;; esac; done
  local data res
  data="$(parse_registry)"
  res="$(awk -F'\t' -v p="$plat" -v i="$id" '
    $1=="ITEM"{idn=$2+0; kind=$3; key=$4}
    $1=="NAME" && ($2+0)==idn {name=$3}
    $1=="ID" && ($2+0)==idn && tolower($3)==tolower(p) && $4==i { if(name!="") printf "%s\t%s\t%s\n", key,name,kind; else printf "%s\t\t%s\n", key,kind; found=1 }
    END{if(!found) exit 3; else exit 0}
  ' <<< "$data")"
  local rc=$?
  [ $rc -ne 0 ] && exit 3
  [ -z "$res" ] && exit 3
  if [ $json -eq 1 ]; then awk -F'\t' '{printf "{\"key\":\"%s\",\"name\":\"%s\",\"kind\":\"%s\"}\n",$1,$2,$3}' <<< "$res" | head -1
  else echo "$res" | head -1; fi
}

cmd_find() {
  need_reg
  local role="" kind="" json=0
  while [ $# -gt 0 ]; do case "$1" in --role) role="$2"; shift 2;; --kind) kind="$2"; shift 2;; --json) json=1; shift;; *) shift;; esac; done
  [ -n "$role" ] || usage
  local data res
  data="$(parse_registry)"
  res="$(awk -F'\t' -v r="$role" -v k="$kind" '
    BEGIN{IGNORECASE=1}
    $1=="ITEM"{cid=$2+0; cik=$3; ckey=$4}
    $1=="ROLE" && ($2+0)==cid { if(tolower($3)==tolower(r)){ if(k==""||tolower(cik)==tolower(k)) print ckey } }
  ' <<< "$data")"
  [ -z "$res" ] && exit 0
  if [ $json -eq 1 ]; then printf '%s\n' "$res" | awk 'NF{gsub(/"/,"\\\""); printf "\"%s\",\n",$0}' | sed '$ s/,$//' | awk 'BEGIN{print "["} {if($0!="") print} END{print "]"}'
  else printf '%s\n' "$res"; fi
}

cmd_assignee() {
  need_reg
  [ $# -ge 1 ] || usage
  local ws json=0; ws="$(normalize_path "$1")"; shift
  while [ $# -gt 0 ]; do case "$1" in --json) json=1; shift;; *) shift;; esac; done
  local data line
  data="$(parse_registry)"
  line="$(awk -F'\t' -v w="$ws" '$1=="ASGN" && $2==w {print $3; exit}' <<< "$data")"
  if [ -z "$line" ]; then
    local best="" bestlen=0
    while IFS=$'\t' read -r t w rest; do [ "$t" != "ASGN" ] && continue; [ -z "$w" ] && continue; case "$ws" in $w) l=${#w}; if [ ${l:-0} -gt $bestlen ]; then best="$rest"; bestlen=$l; fi;; esac; done <<< "$data"
    line="$best"
  fi
  if [ -z "${line:-}" ] || [ "$line" = "[]" ] || [ "$line" = "" ]; then echo "ask"; return 0; fi
  local keys; keys="$(printf '%s' "$line" | tr ',' '\n' | sed -e 's/^[ \t]*//;s/[ \t]*$//' -e 's/["\047]//g' -e '/^$/d')"
  [ -z "$keys" ] && { echo "ask"; return 0; }
  if [ $json -eq 1 ]; then printf '%s\n' "$keys" | awk 'NF{gsub(/"/,"\\\""); printf "\"%s\",\n",$0}' | sed '$ s/,$//' | awk 'BEGIN{print "["} {if($0!="") print} END{print "]"}'
  else printf '%s\n' "$keys"; fi
}

cmd_lint() {
  need_reg
  local strict=0 json=0
  while [ $# -gt 0 ]; do case "$1" in --strict) strict=1; shift;; --json) json=1; shift;; *) shift;; esac; done
  local data errs=0; data="$(parse_registry)"
  local dups; dups="$(awk -F'\t' '$1=="ITEM"{print $4}' <<< "$data" | sort | uniq -d)"
  if [ -n "$dups" ]; then echo "team.sh: duplicate keys: $dups" >&2; errs=$((errs+1)); fi
  if ! awk -F'\t' 'BEGIN{bad=0} $1=="ITEM"{id=$2+0;key=$4;hasn=0} $1=="NAME"&&($2+0)==id{hasn=1} END{if(hasn==0 && key!=""){print "missing name for " key > "/dev/stderr"; exit 1}}' <<< "$data"; then errs=$((errs+1)); fi
  [ $errs -gt 0 ] && exit 1; exit 0
}

cmd_get() {
  need_reg
  [ $# -ge 1 ] || usage
  local key="$1" field="${2:-}"; data="$(parse_registry)"
  if [ -z "$field" ]; then awk -F'\t' -v k="$key" '$1=="ITEM"&&$4==k{id=$2+0} $1=="NAME"&&($2+0)==id{print "name: "$3} $1=="ROLE"&&($2+0)==id{print "role: "$3} $1=="TITLE"&&($2+0)==id{print "title: "$3} $1=="ID"&&($2+0)==id{print "ids."$3": "$4}' <<< "$data"; return 0; fi
  if [[ "$field" == ids.* ]]; then local p="${field#ids.}"; awk -F'\t' -v k="$key" -v p="$p" 'BEGIN{IGNORECASE=1} $1=="ITEM"&&$4==k{id=$2+0} $1=="ID"&&($2+0)==id&&tolower($3)==tolower(p){print $4}' <<< "$data"; return 0; fi
  awk -F'\t' -v k="$key" -v f="$field" 'BEGIN{IGNORECASE=1} $1=="ITEM"&&$4==k{id=$2+0} tolower($1)==tolower(f)&&($2+0)==id{print $3}' <<< "$data"
}

case "${1:-}" in
  whoami) shift; cmd_whoami "$@" ;;
  get) shift; cmd_get "$@" ;;
  find) shift; cmd_find "$@" ;;
  match) shift; cmd_match "$@" ;;
  assignee) shift; cmd_assignee "$@" ;;
  lint) shift; cmd_lint "$@" ;;
  *) usage ;;
esac
