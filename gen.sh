set -euo pipefail

COUNT=$(yq -r '.repos | length' repos.yaml)
eval "$(yq -o=shell repos.yaml)"

cat tpl.Dockerfile

mount_instructions=()
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
  echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget \\"
  echo "    dotnet build \"repo/$repo_sln_rel\" -p:NuGetAudit=false"

  solution_args+=("repos/$repo_name/$repo_sln_rel")
  repo_args+=("/repo:repos/$repo_name=$repo_name=$repo")
  # HtmlGenerator runs MSBuild design-time builds that update files under obj.
  # BuildKit discards writes to these bind mounts after the RUN completes.
  mount_instructions+=("--mount=type=bind,from=$repo_name,source=/app/repo,target=/app/repos/$repo_name,rw")
done

sourcebrowser_sha="$(git ls-remote "https://github.com/Alxandr/SourceBrowser.git" HEAD | cut -f1)"
echo ""
echo "FROM builder AS sourcebrowser"
echo "RUN git init sourcebrowser \\"
echo "    && git -C sourcebrowser remote add origin \"https://github.com/Alxandr/SourceBrowser.git\" \\"
echo "    && git -C sourcebrowser fetch --depth 1 origin \"$sourcebrowser_sha\" \\"
echo "    && git -C sourcebrowser checkout FETCH_HEAD"
echo ""
echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget \\"
echo "    dotnet build \"sourcebrowser/SourceBrowser.slnx\" -c Release -p:DontPack=true"

echo ""
echo "FROM sourcebrowser AS index-builder"
echo ""
echo "RUN --mount=type=cache,id=nuget,target=/root/.nuget \\"
for instruction in "${mount_instructions[@]}"; do
  echo "    $instruction \\"
done
echo -n "    \"sourcebrowser/src/HtmlGenerator/bin/Release/net10.0/HtmlGenerator\" \"/out:out\" /noWarnings"
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
