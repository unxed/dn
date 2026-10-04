DN with UTF-8 inside for DOS (the build DN_UTF8=1). It asks the DOS for the UTF-8 names of files (AMIS DOS-UTF8/NAMES) and the UTF-8 text of the clipboard
(DOS-UTF8/CLIPBRD): go2dos, DOSBox-X with the patches (docs/patches of the repository unxed/dn, dn/TODO-later.md). On a DOS without them the names are what the DOS
gives (the bytes of the code page; a name typed with other characters than ASCII is wrong) and the clipboard goes through the code page: use the plain build (dist/dos) there.
DN_DOS_UTF8_NAMES=0 does not ask for the names, TV_DOS_UTF8_CLIP=0 not for the clipboard.
