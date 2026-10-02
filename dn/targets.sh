# needs $here (the root of the repository) from the script that sources it
# The target of the build (sourced by tools/*.sh): DN_TARGET = dos (default) or linux.
#   DN_TARGET_ENV  the file with the symbols and options of the target
#   DN_TREE        the directory of the tree under build/
#   DN_NEW_DIR     the directory (under the root of the repository) of our files that replace those of dn/new
DN_TARGET=${DN_TARGET:-dos}
case "$DN_TARGET" in
    dos)   DN_TARGET_ENV="$here/dn/target.env";       DN_TREE=dn;       DN_NEW_DIR="" ;;
    linux) DN_TARGET_ENV="$here/dn/target-linux.env"; DN_TREE=dn-linux; DN_NEW_DIR=dn/new-linux ;;
    *) echo "DN_TARGET must be dos or linux" >&2; exit 2 ;;
esac
