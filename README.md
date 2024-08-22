# VFP_RegExp

VFP_RegExp is a class that interfaces with the PCRE Regular Expression engine. It is modelled after the VBScript.RegExp component and aims to replace it.

VFP programmers have been relying on the availability of VBScript.RegExp to address their need for a Regular Expression engine.

Besides lacking more recent and advanced features, Microsoft's announcement of VBScript's deprecation increased the necessity of an alternative.

VFP_RegExp relies on the PCRE2 library as its engine and exposes the same properties and methods as the VBScript engine. Thus, it facilitates migration from the current code while gaining access to many advanced capabilities of PCRE.

In future work, VFP_RegExp will incorporate other PCRE features (like identifying the matched value of named groups, for instance) without compromising compatibility with the VBScript object.

Information on the VBScript.RegExp Object:
- [@ Microsoft](https://learn.microsoft.com/en-us/previous-versions/yab2dx62(v=vs.85))
- [@ Regular Expressions Info](https://www.regular-expressions.info/vbscript.html)

Information on PCRE and PCRE2 library:
- [PCRE2 Project](https://github.com/PCRE2Project/pcre2)
- [Documentation](https://pcre2project.github.io/pcre2/doc/html/index.html)
- [@ Regular Expressions Info](https://www.regular-expressions.info/pcre2.html)

## Properties

Properties marked as `VBS` come from the VBScript object; those marked as `PCRE` are defined by the `PCRE2` library; those marked as `VFP` are determined by the VFP_RegExp class and have some informational or functional value, as described in the table below.

Refer to the respective documentation for those marked as `VBS` or `PCRE`.

|Property|Source|Type|Notes|
|---|---|---|---|
|DotAll|PCRE|L| |
|Extended|PCRE|L| |
|Global|VBS|L| |
|Groups|VFP|N|The number of capturing groups in a regular expression.|
|IgnoreCase|VBS|L| |
|Multiline|VBS|L| |
|NormalizeCRLF|VFP|L|Normalize newlines in a subject string changing them from LF or CR to CR+LF, before matching.|
|RegExpEngine|VFP|C|Name and version of the PCRE2 library.|
|Pattern|VBS|C| |
|RegExpError|VFP|N|Error code found during an PCRE2 operation.|
|RegExpErrorLocation|VFP|C|Where in the pattern a syntactic error was located.|
|RegExpErrorMessage|VFP|C|A message corresponding to the error code.|
|SafetyValve|VFP|N|Set to something greater than zero to prevent infinite or large loops in the matching process.|
|Ungreedy|PCRE|L| |
|Version|VFP|N|The version of the class.|

## Methods

The three methods that the class exposes follow those available in VBScript.RegExp:

### `.Test(SubjectString AS String) AS Logical`

Tests a subject string against the pattern and returns `.T.` if it matches, in whole or partially, or `.F.`, otherwise.

### `.Execute(SubjectString AS String) AS RegExp_MatchCollection`

Matches a subject string against the pattern and returns a collection of matches of the `RegExp_Match` type, organized under a `RegExp_MatchCollection` object.

An application can find the number of matches in the `RegExp_MatchCollection.Count` property, and access an individual match by addressing it through `RegExp_MatchCollection.Item(<0 to .Count - 1>)`.

Every `RegExp_Match` holds a `RegExp_SubMatchesCollection` which, in turn, holds information on every `RegExp_SubMatch` of the match, corresponding to the capturing groups of the regular expression.

The properties and methods of these objects are the same as those found in the corresponding objects in VBScript.

### `.Replace(SubjectString AS String, Replacement AS String) AS String`

Replaces a subject string with a replacement string pattern, which may hold references to the capturing groups in the regular expression (as supported by the VBScript object).

For instance, if the regular expression has two sequential capturing groups, the replacement string `"$2$1"` swaps their positions, and the replacement string `"$1"` removes the contents of the second group.

## Using

To put the class in scope, run the procedure program:

```foxpro
DO regexvfp_pcre
```

The class is used in the same way that a VSCript.RegExp object is instantiated and used:
```foxpro
m.RegExp = CREATEOBJECT("VFP_RegExp")  && instead of "VBScript.RegExp"
m.RegExp.Pattern = "^(\d+(\.[\d]+)?)$"
? m.RegExp.Test("78.230")
```

Since method chaining is not generally possible with VFP native objects, it's necessary to identify each object of the chain.

Therefore, this construction that would possible using a VBScript.RegExp object
```foxpro
? m.RegExp.Execute("78.230").Item(0).SubMatches.Count
```
must be rewritten, for a VFP_RegExp object, as something like
```foxpro
m.Matches = m.RegExp.Execute("78.230")
m.Match = m.Matches.Item(0)
? m.Match.SubMatches.Count
```
or, if not using variables, as
```foxpro
WITH CREATEOBJECT("VFP_RegExp") AS VFP_RegExp
	.Pattern = "^(\d+(\.[\d]+)?)$"
	WITH .Execute("78.230") AS RegExp_MatchCollection
		WITH .Item(0) AS RegExp_Match
			? .SubMatches.Count
		ENDWITH
	ENDWITH
ENDWITH
```

The class requires a PCRE2 8-bit DLL (where 8-bit refers to the size of a character). For convenience, an already-built DLL is available in the source folder, but you can use any other that may be present in your system. Before use, read the accompanying license document.

## Licensing and acknowledgments

[Unlicensed](UNLICENSE.md "Unlicense").

**PCRE2 Basic Library Functions** by Philip Hazel, copyright (c) 1997-2024 University of Cambridge, distributed under a [BSD license](PCRE2_LICENCE "BSD License").

DLL built using the configuration / VS solution in [pcre2-win-build](https://github.com/kiyolee/pcre2-win-build "PCRE2 Windows Build"), by Kelvin Lee.

## Status

In development.
