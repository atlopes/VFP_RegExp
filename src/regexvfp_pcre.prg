*
* VFP_RegExp
*
* A VFP interface to the PCRE2 Regular Expression engine.
*
* Supports the VBScrip.RegExp properties and methods, but the regular expressions syntax and semantics come from PCRE2.
*
* Requires a PCRE2 8 DLL.
*


* some PCRE2 related definitions

* configuration queries

#DEFINE PCRE2_CONFIG_VERSION		11

* error codes

#DEFINE PCRE2_NO_ERROR				0
#DEFINE PCRE2_ERROR_NOMATCH		-1

* pattern compiler options

#DEFINE PCRE2_CASELESS				0x00000008
#DEFINE PCRE2_DOTALL					0x00000020
#DEFINE PCRE2_EXTENDED				0x00000080
#DEFINE PCRE2_MULTILINE				0x00000400
#DEFINE PCRE2_UNGREEDY				0x00040000

* match options

#DEFINE PCRE2_NOTEMPTY_ATSTART	0x00000008
#DEFINE PCRE2_ANCHORED				0x80000000

* VFP_RegExp related definitions

#DEFINE VFP_REG_TEST			0
#DEFINE VFP_REG_EXEC			1
#DEFINE VFP_REG_REPLACE		2

#DEFINE AS_DWORD				"4RS"

* run this program to put the class in scope
* and to declare the pcre2_* functions

IF _VFP.StartMode == 0
	SET PATH TO (JUSTPATH(SYS(16))) ADDITIVE
ENDIF

SET PROCEDURE TO (SYS(16)) ADDITIVE

CREATEOBJECT("RegExp_Library")

* see accompanying documentation for details

DEFINE CLASS VFP_RegExp AS Custom

	Version = 1.01
	RegExpEngine = ""
	MatchCollectionBaseClass = "Custom"

	* VBScript-like properties
	Global = .F.
	IgnoreCase = .F.
	Multiline = .F.
	Pattern = ""

	* PCRE2 flags
	DotAll = .F.
	Extended = .F.
	Ungreedy = .F.

	RegExpError = 0
	RegExpErrorLocation = ""
	RegExpErrorMessage = ""

	SafetyValve = -1
	NormalizeCRLF = .F.

	Groups = 0

	_MemberData = "<VFPData>" + ;
						"<memberdata name='dotall' display='DotAll' type='property'/>" + ;
						"<memberdata name='extended' display='Extended' type='property'/>" + ;
						"<memberdata name='global' display='Global' type='property'/>" + ;
						"<memberdata name='groups' display='Groups' type='property'/>" + ;
						"<memberdata name='ignorecase' display='IgnoreCase' type='property'/>" + ;
						"<memberdata name='multiline' display='Multiline' type='property'/>" + ;
						"<memberdata name='matchcollectionbaseclass' display='MatchCollectionBaseClass' type='property'/>" + ;
						"<memberdata name='normalizecrlf' display='NormalizeCRLF' type='property'/>" + ;
						"<memberdata name='regexpengine' display='RegExpEngine' type='property'/>" + ;
						"<memberdata name='pattern' display='Pattern' type='property'/>" + ;
						"<memberdata name='regexperror' display='RegExpError' type='property'/>" + ;
						"<memberdata name='regexperrorlocation' display='RegExpErrorLocation' type='property'/>" + ;
						"<memberdata name='regexperrormessage' display='RegExpErrorMessage' type='property'/>" + ;
						"<memberdata name='safetyvalve' display='SafetyValve' type='property'/>" + ;
						"<memberdata name='ungreedy' display='Ungreedy' type='property'/>" + ;
						"<memberdata name='version' display='Version' type='property'/>" + ;
						;
						"<memberdata name='execute' display='Execute' type='method'/>" + ;
						"<memberdata name='replace' display='Replace' type='method'/>" + ;
						"<memberdata name='test' display='Test' type='method'/>" + ;
						"</VFPData>"

	FUNCTION Init ()

			LOCAL PCREVersion AS String
			LOCAL PCREBuffLen AS Integer

			m.PCREBuffLen = pcre2_GetConfigInfo(PCRE2_CONFIG_VERSION, 0)
			IF m.PCREBuffLen > 0
				m.PCREVersion = SPACE(m.PCREBuffLen + 1)
				pcre2_GetConfigInfo(PCRE2_CONFIG_VERSION, @m.PCREVersion)
			ELSE
				m.PCREVersion = ""
			ENDIF

			This.RegExpEngine = TRIM("PCRE2 " + m.PCREVersion, 0, 0h00, " ")

	ENDFUNC

	* Perform the actual operation (Test, Execute, or Replace).

	* Test: returns true if the subject string (at least, partially) matches the pattern.

	FUNCTION Test (SubjectString AS String) AS Object

		IF This.NormalizeCRLF
			RETURN This.RegExpOp(VFP_REG_TEST, This.Normalizer(m.SubjectString))
		ELSE
			RETURN This.RegExpOp(VFP_REG_TEST, m.SubjectString)
		ENDIF

	ENDFUNC

	* Execute: returns a collection of RegExp_Match objects (number of matches in RegExp_MatchColletion.Count).

	FUNCTION Execute (SubjectString AS String) AS Object

		IF This.NormalizeCRLF
			RETURN This.RegExpOp(VFP_REG_EXEC, This.Normalizer(m.SubjectString))
		ELSE
			RETURN This.RegExpOp(VFP_REG_EXEC, m.SubjectString)
		ENDIF

	ENDFUNC

	* Replace: returns a string in which capture groups are replaced by a reference in a replacement string.

	FUNCTION Replace (SubjectString AS String, Replacement AS String) AS String

		IF This.NormalizeCRLF
			RETURN This.RegExpOp(VFP_REG_REPLACE, This.Normalizer(m.SubjectString), m.Replacement)
		ELSE
			RETURN This.RegExpOp(VFP_REG_REPLACE, m.SubjectString, m.Replacement)
		ENDIF

	ENDFUNC

	* Execute the pattern against the subject string, optionally replacing matched groups.

	HIDDEN FUNCTION RegExpOp (Operation AS Integer, SubjectString AS String, Replacement AS String) AS ObjectOrString

		LOCAL PCRE AS Integer
		LOCAL MatchData AS Integer
		LOCAL MatchVector AS Integer
		LOCAL MatchOptions AS Integer

		LOCAL ErrorCode AS Integer
		LOCAL ErrorMessage AS String
		LOCAL ErrorOffset AS Integer
		LOCAL ResultCode AS Integer

		LOCAL SafetyValve AS Integer

		LOCAL Ops AS Exception

		* method results
		LOCAL Matched AS Logical
		LOCAL Replaced AS String
		LOCAL RunningMatches AS RegExp_MatchCollection

		LOCAL Match AS RegExp_Match, SubMatch AS RegExp_SubMatch

		LOCAL StartMatch AS Integer, EndMatch AS Integer
		LOCAL Offset AS Integer

		LOCAL Group AS Integer

		* the possible results that may be returned
		m.Matched = .F.
		m.Replaced = ""
		m.RunningMatches = .NULL.
		
		This.Groups = 0

		This.RegExpError = PCRE2_NO_ERROR
		This.RegExpErrorLocation = ""
		This.RegExpErrorMessage = ""

		* no allocated structures, for now
		STORE 0 TO m.PCRE, m.MatchData

		* let's not run in an infinite loop
		m.SafetyValve = This.SafetyValve

		TRY

			* try to compile the pattern
			STORE 0 TO m.ErrorCode, m.ErrorOffset
			m.PCRE = pcre2_Compile(This.Pattern, LEN(This.Pattern), This.CompileFlags(), @m.ErrorCode, @m.ErrorOffset, 0)

			* if succeded, we now have a pointer to a PCRE control structure
			IF m.PCRE != 0

				* prepare the collection of matches
				IF m.Operation != VFP_REG_TEST
					m.RunningMatches = CREATEOBJECT(IIF(This.MatchCollectionBaseClass == "Collection", "RegExp_MatchCollection2", "RegExp_MatchCollection"))
				ENDIF

				* prepare the structure that will store info on matches on the PCRE2 side
				m.MatchData = pcre2_PrepareMatchData(m.PCRE, 0)

				* all set to go?
				IF ! EMPTY(m.MatchData)

					* perform (a first|the) match
					m.ResultCode = pcre2_Match(m.PCRE, m.SubjectString, LEN(m.SubjectString), 0, 0, m.MatchData, 0)

					DO CASE

					* error or no match?
					CASE m.ResultCode < PCRE2_NO_ERROR

						* signal any error other than no match
						IF m.ResultCode != PCRE2_ERROR_NOMATCH
							This.RegExpError = m.ResultCode
						ENDIF

					* no error and we were testing for a match?
					CASE m.Operation == VFP_REG_TEST

						* will return True
						m.Matched = .T.

					* no error, and we proceed to execute or replace
					OTHERWISE

						* process the first match and get the output vector, with info on substrings
						m.MatchVector = pcre2_GetOutputVectorPointer(m.MatchData)

						* information on where the matches occured
						m.StartMatch = This.ReadInt(m.MatchVector)
						m.EndMatch = This.ReadInt(m.MatchVector + 4)

						* if in replace mode, begin to fetch the start of the string that did not match (it may be empty)
						IF m.Operation == VFP_REG_REPLACE
							m.Replaced = LEFT(m.SubjectString, m.StartMatch)
						ENDIF

						* store the info on the first match, overall string
						m.Match = This.MatchRecorder(m.RunningMatches, m.SubjectString, m.MatchVector, m.ResultCode)

						* to-do: query the library, instead, but this will work, for now
						This.Groups = MAX(This.Groups, m.ResultCode)

						* replace what was matched, if we are in replace mode
						IF m.Operation == VFP_REG_REPLACE
							m.Replaced = This.Replacer(m.Replaced, m.Replacement, m.Match)
						ENDIF

						* when global, continue beyond the first match
						IF This.Global

							DO WHILE m.SafetyValve != 0

								* prevent infinite/too deep loops, if needed
								IF m.SafetyValve > 0
									m.SafetyValve = m.SafetyValve - 1
								ENDIF

								m.MatchOptions = 0

								* where are we, while matching the subject string
								m.StartMatch = This.ReadInt(m.MatchVector)
								m.EndMatch = This.ReadInt(m.MatchVector + 4)
								m.Offset = m.EndMatch

								* deal with empty strings
								IF m.StartMatch == m.EndMatch

									* unless we reached the end
									IF m.StartMatch == LEN(m.SubjectString)
										EXIT
									ENDIF

									m.MatchOptions = BITOR(PCRE2_NOTEMPTY_ATSTART, PCRE2_ANCHORED)

								ELSE

									* deal with \K references, that discard previous contents
									m.StartMatch = pcre2_GetStart(m.MatchData)
									IF m.Offset <= m.StartMatch
										IF m.StartMatch >= LEN(m.SubjectString)
											EXIT
										ENDIF
										m.Offset = m.Offset + m.StartMatch + 1
									ENDIF

								ENDIF

								* execute
								m.ResultCode = pcre2_Match(m.PCRE, m.SubjectString, LEN(m.SubjectString), m.Offset, m.MatchOptions, m.MatchData, 0)

								IF m.ResultCode == PCRE2_ERROR_NOMATCH

									* no more subject string to match
									IF EMPTY(m.MatchOptions)
										EXIT
									ENDIF

									* otherwise, skip next char, or CRLF
									IF m.Offset < LEN(m.SubjectString) - 1 AND SUBSTR(m.SubjectString, m.Offset + 1, 2) == 0h0d0a
										This.WriteInt(m.MatchVector + 4, m.Offset + 2)
									ELSE
										This.WriteInt(m.MatchVector + 4, m.Offset + 1)
									ENDIF

									* and continue
									LOOP

								ENDIF

								* break with any error other than no match
								IF m.ResultCode < PCRE2_NO_ERROR
									This.RegExpError = m.ResultCode
									EXIT
								ENDIF

								* we have a new match, record it as above
								m.Match = This.MatchRecorder(m.RunningMatches, m.SubjectString, m.MatchVector, m.ResultCode)

								IF m.Operation == VFP_REG_REPLACE
									m.Replaced = This.Replacer(m.Replaced, m.Replacement, m.Match)
								ENDIF

							ENDDO

						ENDIF

						* if in replace mode, get the remaining of the string that didn't match
						IF m.Operation == VFP_REG_REPLACE
							m.Replaced = m.Replaced + SUBSTR(m.SubjectString, m.Offset + 1)
						ENDIF

					ENDCASE
	
				ENDIF

			ENDIF
	
			* report error
			IF This.RegExpError != PCRE2_NO_ERROR
				m.ErrorMessage = SPACE(256)
				pcre2_GetErrorMessage(This.RegExpError, @m.ErrorMessage, LEN(m.ErrorMessage) - 1)
				This.RegExpErrorMessage = STREXTRACT(m.ErrorMessage, "", 0h00, 1, 2)
				This.RegExpErrorLocation = SUBSTR(This.Pattern, m.ErrorOffset + 1)
			ENDIF

		CATCH TO m.Ops

			* something went wrong
			SET STEP ON
			
		FINALLY

			* free PCRE2 structures
			IF m.MatchData != 0
				pcre2_FreeMatchData(m.MatchData)
			ENDIF
			IF m.PCRE != 0
				pcre2_Free(m.PCRE)
			ENDIF

		ENDTRY

		DO CASE
		CASE m.Operation == VFP_REG_TEST
			RETURN m.Matched
		CASE m.Operation == VFP_REG_EXEC
			RETURN m.RunningMatches
		CASE m.Operation == VFP_REG_REPLACE
			RETURN m.Replaced
		OTHERWISE
			RETURN .NULL.
		ENDCASE

	ENDFUNC

	* replace, using VBScript.RegExp semantics
	HIDDEN FUNCTION Replacer (ReplacedString AS String, ReplacementString AS String, Match AS RegExp_Match) AS String

		LOCAL ScanReplacement AS Integer
		LOCAL NewReplacedString AS String
		LOCAL ReplaceChar AS Character
		LOCAL Group AS Integer

		m.NewReplacedString = m.ReplacedString

		m.ScanReplacement = 1
		DO WHILE m.ScanReplacement <= LEN(m.ReplacementString)

			m.ReplaceChar = SUBSTR(m.ReplacementString, m.ScanReplacement, 1)

			* reference to groups are made in the form $n
			IF m.ReplaceChar == "$"

				m.ScanReplacement = m.ScanReplacement + 1
				m.ReplaceChar = SUBSTR(m.ReplacementString, m.ScanReplacement, 1)

				IF BETWEEN(m.ReplaceChar, "1", "9") OR m.ReplaceChar == "&"

					m.Group = IIF(m.ReplaceChar == "&", 1, VAL(m.ReplaceChar))

					IF m.Group <= This.Groups
						m.NewReplacedString = m.NewReplacedString + NVL(m.Match.SubMatches.Item(m.Group - 1), "")
					ELSE
						m.NewReplacedString = m.NewReplacedString + "$" + m.ReplaceChar
					ENDIF

				ELSE

					m.NewReplacedString = m.NewReplacedString + "$" + m.ReplaceChar

				ENDIF

			ELSE

				m.NewReplacedString = m.NewReplacedString + m.ReplaceChar

			ENDIF
			
			m.ScanReplacement = m.ScanReplacement + 1

		ENDDO

		RETURN m.NewReplacedString

	ENDFUNC

	* record a match and submatches
	HIDDEN FUNCTION MatchRecorder (Matches AS RegExp_MatchCollection, Subject AS String, Vector AS Integer, Groups AS Integer) AS RegExp_Match

		LOCAL Match AS RegExp_Match
		LOCAL Start AS Integer, End AS Integer
		LOCAL Group AS Integer

		* the overall match
		m.Start = This.ReadInt(m.Vector)
		m.End = This.ReadInt(m.Vector + 4)

		m.Match = m.Matches.MatchFound(m.Start, m.End - m.Start, SUBSTR(m.Subject, m.Start + 1, m.End - m.Start))

		* info on capture groups (if any)
		FOR m.Group = 1 TO m.Groups - 1

			m.Start = This.ReadInt(m.Vector + 8 * m.Group)
			m.End = This.ReadInt(m.Vector + 8 * m.Group + 4)

			IF m.Start != -1
				m.Match.SubMatches.MatchFound(m.Group, m.Start, m.End - m.Start, SUBSTR(m.Subject, m.Start + 1, m.End - m.Start))
			ELSE
				m.Match.SubMatches.MatchNotFound(m.Group)
			ENDIF

		ENDFOR

		RETURN m.Match

	ENDFUNC

	* make all newlines like CRLF, if there is no CRLF in the subject string
	HIDDEN FUNCTION Normalizer (Source AS String) AS String

		IF ! 0h0d0a $ m.Source 
			IF 0h0d $ m.Source
				RETURN STRTRAN(m.Source, 0h0d, 0h0d0a)
			ELSE
				IF 0h0a $ m.Source
					RETURN STRTRAN(m.Source, 0h0a, 0h0d0a)
				ENDIF
			ENDIF
		ENDIF

		RETURN m.Source

	ENDFUNC

	* set the PCRE2 flags corresponding to IgnoreCase and Multiline, and other specific PCRE2 flags
	HIDDEN FUNCTION CompileFlags () AS Integer

		LOCAL cFlags AS Integer

		m.cFlags = 0
		IF This.IgnoreCase
			m.cFlags = BITOR(m.cFlags, PCRE2_CASELESS)
		ENDIF
		IF This.Multiline
			m.cFlags = BITOR(m.cFlags, PCRE2_MULTILINE)
		ENDIF
		IF This.Extended
			m.cFlags = BITOR(m.cFlags, PCRE2_EXTENDED)
		ENDIF
		IF This.DotAll
			m.cFlags = BITOR(m.cFlags, PCRE2_DOTALL)
		ENDIF
		IF This.Ungreedy
			m.cFlags = BITOR(m.cFlags, PCRE2_UNGREEDY)
		ENDIF

		RETURN m.cFlags

	ENDFUNC

	* auxiliary functions to peek and poke memory
	HIDDEN FUNCTION ReadInt (MemoryLocation AS Integer) AS Integer

		RETURN CTOBIN(SYS(2600, m.MemoryLocation, 4), AS_DWORD)

	ENDFUNC

	HIDDEN PROCEDURE WriteInt (MemoryLocation AS Integer, Value AS Integer)

		SYS(2600, m.MemoryLocation, 4, BINTOC(m.Value, AS_DWORD))

	ENDPROC

ENDDEFINE

* a collection of matches (BaseClass == "Custom")

DEFINE CLASS Regexp_MatchCollection AS Custom

	Count = 0

	HIDDEN Matches[1]
	DIMENSION Matches[1]

	_MemberData = "<VFPData>" + ;
						"<memberdata name='count' display='Count' type='property'/>" + ;
						;
						"<memberdata name='item' display='Item' type='method'/>" + ;
						"</VFPData>"

	FUNCTION Init
		This.Matches[1] = .NULL.
	ENDFUNC

	* as in VBScript, index is 0-based
	FUNCTION Item (matchIndex AS Integer) AS RegExp_Match

		IF BETWEEN(m.matchIndex, 0, This.Count - 1)
			RETURN This.Matches[m.matchIndex + 1]
		ELSE
			RETURN .NULL.
		ENDIF

	ENDFUNC

	* (part of the) subject string has matched
	FUNCTION MatchFound (FirstIndex AS Integer, Length AS Integer, Value AS String) AS RegExp_Match

		LOCAL Match AS RegExp_Match

		m.Match = CREATEOBJECT("RegExp_Match")

		WITH m.Match AS RegExp_Match

			.FirstIndex = m.FirstIndex
			.Length = m.Length
			.Value = m.Value

		ENDWITH

		This.Count = This.Count + 1
		DIMENSION This.Matches[This.Count]
		This.Matches[This.Count] = m.Match

		RETURN m.Match

	ENDFUNC

ENDDEFINE

* a collection of matches (BaseClass == "Collection")

DEFINE CLASS Regexp_MatchCollection2 AS Collection

	* (part of the) subject string has matched
	FUNCTION MatchFound (FirstIndex AS Integer, Length AS Integer, Value AS String) AS RegExp_Match

		LOCAL Match AS RegExp_Match

		m.Match = CREATEOBJECT("RegExp_Match", .T.)

		WITH m.Match AS RegExp_Match

			.FirstIndex = m.FirstIndex
			.Length = m.Length
			.Value = m.Value

		ENDWITH

		This.Add(m.Match)

		RETURN m.Match

	ENDFUNC

ENDDEFINE

* a match

DEFINE CLASS RegExp_Match AS Custom

	FirstIndex = 0
	Length = 0
	Value = ""
	SubMatches = .NULL.

	_MemberData = "<VFPData>" + ;
						"<memberdata name='firstindex' display='FirstIndex' type='property'/>" + ;
						"<memberdata name='length' display='Length' type='property'/>" + ;
						"<memberdata name='submatches' display='SubMatches' type='property'/>" + ;
						"<memberdata name='value' display='Value' type='property'/>" + ;
						"</VFPData>"

	PROCEDURE Init (BaseClassIsCollection AS Logical)
		This.SubMatches = CREATEOBJECT(IIF(m.BaseClassIsCollection, "RegExp_SubMatchCollection2", "RegExp_SubMatchCollection"))
	ENDPROC

ENDDEFINE

* a collection of submatches (BaseClass == "Custom")

DEFINE CLASS RegExp_SubMatchCollection AS Custom

	Count = 0

	HIDDEN SubMatches[1]
	DIMENSION SubMatches[1]

	_MemberData = "<VFPData>" + ;
						"<memberdata name='count' display='Count' type='property'/>" + ;
						;
						"<memberdata name='item' display='Item' type='method'/>" + ;
						"</VFPData>"

	FUNCTION Init
		This.SubMatches[1] = .NULL.
	ENDFUNC

	* as in VBScript, index is 0-based
	FUNCTION Item (matchIndex AS Integer) AS String

		IF BETWEEN(m.matchIndex, 0, This.Count - 1)
			RETURN This.SubMatches[m.matchIndex + 1].Value
		ELSE
			RETURN .NULL.
		ENDIF

	ENDFUNC

	* (part of the) subject string has matched, as result of a capture group
	FUNCTION MatchFound (Group AS Integer, FirstIndex AS Integer, Length AS Integer, Value AS String) AS RegExp_SubMatch

		LOCAL SubMatch AS RegExp_SubMatch

		m.SubMatch = CREATEOBJECT("RegExp_SubMatch")

		WITH m.SubMatch

			.Group = m.Group
			.FirstIndex = m.FirstIndex
			.Length = m.Length
			.Value = m.Value

		ENDWITH

		This.Count = This.Count + 1
		DIMENSION This.SubMatches[This.Count]

		This.SubMatches[This.Count] = m.SubMatch

		RETURN m.SubMatch

	ENDFUNC

	* no match for a specific capture group
	FUNCTION MatchNotFound (Group AS Integer) AS RegExp_SubMatch

		RETURN This.MatchFound(m.Group, .NULL., .NULL., .NULL.)

	ENDFUNC

ENDDEFINE

* a collection of submatches (BaseClass == "Collection")

DEFINE CLASS RegExp_SubMatchCollection2 AS Collection

	* (part of the) subject string has matched, as result of a capture group
	FUNCTION MatchFound (Group AS Integer, FirstIndex AS Integer, Length AS Integer, Value AS String) AS RegExp_SubMatch

		LOCAL Match AS RegExp_SubMatch

		m.SubMatch = CREATEOBJECT("RegExp_SubMatch")

		WITH m.SubMatch

			.Group = m.Group
			.FirstIndex = m.FirstIndex
			.Length = m.Length
			.Value = m.Value

		ENDWITH

		This.Add(m.SubMatch)

		RETURN m.SubMatch

	ENDFUNC

	* no match for a specific capture group
	FUNCTION MatchNotFound (Group AS Integer) AS RegExp_SubMatch

		RETURN This.MatchFound(m.Group, .NULL., .NULL., .NULL.)

	ENDFUNC

ENDDEFINE

* a submatch

DEFINE CLASS RegExp_SubMatch AS Custom

	FirstIndex = 0
	Length = 0
	Value = ""
	Group = 0

	_MemberData = "<VFPData>" + ;
						"<memberdata name='firstindex' display='FirstIndex' type='property'/>" + ;
						"<memberdata name='group' display='Group' type='property'/>" + ;
						"<memberdata name='length' display='Length' type='property'/>" + ;
						"<memberdata name='value' display='Value' type='property'/>" + ;
						"</VFPData>"
ENDDEFINE

* the library loader

DEFINE CLASS RegExp_Library AS Custom

	PROCEDURE Init

		LOCAL RegexDLL AS String

		m.RegexDLL = "libpcre2-8.dll"

		DECLARE LONG pcre2_compile_8 IN (m.RegexDLL) AS pcre2_Compile ;
			STRING pattern, ;
			INTEGER length, ;
			INTEGER options, ;
			INTEGER @ errorcode, ;
			INTEGER @ erroroffset, ;
			LONG context

		DECLARE LONG pcre2_match_data_create_from_pattern_8 IN (m.RegexDLL) AS pcre2_PrepareMatchData ;
			LONG code, ;
			LONG gcontext

		DECLARE INTEGER pcre2_match_8 IN (m.RegexDLL) AS pcre2_Match ;
			LONG code, ;
			STRING subject, ;
			INTEGER length, ;
			INTEGER startoffset, ;
			INTEGER options, ;
			LONG match_data, ;
			LONG mcontext

		DECLARE LONG pcre2_get_ovector_pointer_8 IN (m.RegexDLL) AS pcre2_GetOutputVectorPointer	 ;
			LONG match_data

		DECLARE INTEGER pcre2_get_startchar_8 IN (m.RegexDLL) AS pcre2_GetStart ;
			LONG match_data

		DECLARE pcre2_code_free_8 IN (m.RegexDLL) AS pcre2_Free ;
			LONG code

		DECLARE pcre2_match_data_free_8 IN (m.RegexDLL) AS pcre2_FreeMatchData ;
			LONG match_data

		DECLARE pcre2_get_error_message_8 IN (m.RegexDLL) AS pcre2_GetErrorMessage ;
			INTEGER errorcode, ;
			STRING @ buffer, ;
			INTEGER bufflen

		DECLARE INTEGER pcre2_config_8 IN (m.RegexDLL) AS pcre2_GetConfigInfo ;
			INTEGER what, ;
			STRING @ where

	ENDPROC

ENDDEFINE
