#!/usr/bin/env bash

set -euo pipefail

COUNT=$(yq -r '.repos | length' repos.yaml)
eval $(yq -oshell repos.yaml)

mkdir -p repos
generator_args=()
for ((i = 0; i < COUNT; i++)); do
  repo_var="repos_${i}_repo"
  name_var="repos_${i}_name"
  sln_var="repos_${i}_sln"
  repo="${!repo_var}"
  repo_name="${!name_var}"
  repo_sln="repos/${repo_name}/${!sln_var}"
  

  if [[ ! -d "repos/$repo_name" ]]; then
    echo "Fetching $repo into $repo_name..."

    git clone --depth 1 "$repo" "repos/$repo_name"
    if [[ ! -f "$repo_sln" ]]; then
      echo "Error: File $repo_sln does not exist. Please check the repository and solution path."
      exit 1
    fi

    dotnet build "$repo_sln"
  fi

  generator_args+=("$repo_sln" "/repo:repos/$repo_name=$repo_name=$repo")
done

if [[ ! -d "sourcebrowser" ]]; then
  echo "Fetching SourceBrowser..."
  git clone https://github.com/Alxandr/SourceBrowser.git sourcebrowser
  dotnet restore sourcebrowser/SourceBrowser.slnx
fi

if [[ ! -f "sourcebrowser/bin/HtmlGenerator" ]]; then
  dotnet build sourcebrowser/src/HtmlGenerator/HtmlGenerator.csproj -c Release -o sourcebrowser/bin -p:DontPack=true --no-restore
fi

echo "Generating source browser output..."
rm -rf out
export MSBUILDDISABLENODEREUSE=1

set -x
"sourcebrowser/bin/HtmlGenerator" "/out:out" "${generator_args[@]}"
