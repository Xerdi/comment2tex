## A short annotated Bash source.  Double-hash lines become prose,
## everything else is code.
echo "building"
for f in *.tex; do
  lualatex --interaction=nonstopmode "$f"
done
