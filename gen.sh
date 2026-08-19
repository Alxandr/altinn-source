set -euo pipefail

COUNT=$(yq -r '.repos | length' repos.yaml)
eval "$(yq -o=shell repos.yaml)"

cat tpl.Dockerfile

copy_instructions=()
solution_args=()
repo_args=()
for ((i = 0; i < COUNT; i++)); do
  repo_var="repos_${i}_repo"
  name_var="repos_${i}_name"
  sln_var="repos_${i}_sln"

  repo="${!repo_var}"
  repo_name="${!name_var}"
  repo_sln_rel="${!sln_var}"

  sha="$(git ls-remote "$repo" HEAD | cut -f1)"

  echo ""
  echo "FROM builder AS $repo_name"
  echo "RUN git init repo \\"
  echo "    && git -C repo remote add origin \"$repo\" \\"
  echo "    && git -C repo fetch --depth 1 origin \"$sha\" \\"
  echo "    && git -C repo checkout FETCH_HEAD"
  echo ""
  echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages,sharing=locked \\"
  echo "    dotnet build \"repo/$repo_sln_rel\" -p:NuGetAudit=false"

  solution_args+=("repos/$repo_name/$repo_sln_rel")
  repo_args+=("/repo:repos/$repo_name=$repo_name=$repo")
  copy_instructions+=("COPY --from=$repo_name \"/app/repo\" \"./repos/$repo_name\"")
done

sourcebrowser_sha="$(git ls-remote "https://github.com/Alxandr/SourceBrowser.git" HEAD | cut -f1)"
echo ""
echo "FROM builder AS sourcebrowser"
echo "RUN git init sourcebrowser \\"
echo "    && git -C sourcebrowser remote add origin \"https://github.com/Alxandr/SourceBrowser.git\" \\"
echo "    && git -C sourcebrowser fetch --depth 1 origin \"$sourcebrowser_sha\" \\"
echo "    && git -C sourcebrowser checkout FETCH_HEAD"
echo ""
echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages,sharing=locked \\"
echo "    dotnet build \"sourcebrowser/SourceBrowser.slnx\" -c Release -p:DontPack=true"

echo ""
echo "FROM sourcebrowser AS index-builder"
for instruction in "${copy_instructions[@]}"; do
  echo "$instruction"
done
echo ""
echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages,sharing=locked \\"
echo -n "    \"sourcebrowser/src/HtmlGenerator/bin/Release/net10.0/HtmlGenerator\" \"/out:out\""
for solution in "${solution_args[@]}"; do
  echo " \\"
  echo -n "    \"$solution\""
done
for repo in "${repo_args[@]}"; do
  echo " \\"
  echo -n "    \"$repo\""
done
echo ""

echo ""
echo "FROM runtime AS final"
echo "COPY --from=index-builder /app/out ."
echo "ENTRYPOINT [\"tini\", \"--\"]"
echo "CMD [\"/app/Microsoft.SourceBrowser.SourceIndexServer\"]"
