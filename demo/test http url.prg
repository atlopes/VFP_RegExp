*
* test for an HTTP URL
*
* show case:
*
*  - extended mode
*  - named groups
*  - subpatterns references
*

DO LOCFILE("regexvfp_pcre.prg")

LOCAL RX AS VFP_RegExp

m.RX = CREATEOBJECT("VFP_RegExp")

m.RX.Extended = .T.

LOCAL RxPattern AS String

TEXT TO m.RxPattern NOSHOW FLAGS 1

(?(DEFINE)
  (?<scheme>(https?://))
)

(?(DEFINE)
  (?<safe>[\$\-\_\.\+])
)

(?(DEFINE)
  (?<extra>[\!\*\'\(\)\,])
)

(?(DEFINE)
  (?<reserved>[\;\/\?\:\@\&\=])
)

(?(DEFINE)
  (?<hex>[0-9a-fA-F])
)

(?(DEFINE)
  (?<escape>\%\g<hex>{2})
)

(?(DEFINE)
  (?<unreserved>(\p{L}|\d|\g<safe>|\g<extra>))
)

(?(DEFINE)
  (?<uchar>\g<unreserved>|\g<escape>)
)

(?(DEFINE)
  (?<additional1>[\;\?\&\=])
)

(?(DEFINE)
  (?<additional2>[\;\:\@\&\=])
)

(?(DEFINE)
  (?<login>(\g<uchar>|\g<additional1>)+(:(\g<uchar>|\g<additional1>)+)?@)
)

(?(DEFINE)
  (?<ipv4part>((25[0-5])|(2[0-4][0-9])|([0-1]?[0-9][0-9]?)))
)

(?(DEFINE)
  (?<ipv4>(\g<ipv4part>\.){3}(\g<ipv4part>))
)

(?(DEFINE)
  (?<ipv6part>(\g<hex>{1,4}))
)

(?(DEFINE)
  (?<cipv6part>(:\g<ipv6part>))
)

(?(DEFINE)
  (?<ipv6partc>(\g<ipv6part>:))
)

(?(DEFINE)
  (?<ipv6>(\[(
    (\g<ipv6partc>{7}\g<ipv6part>)
    |(\g<ipv6partc>{5}\g<cipv6part>)
    |(\g<ipv6partc>{4}\g<cipv6part>{1,2})
    |(\g<ipv6partc>{4}\g<cipv6part>?(:\g<ipv4>))
    |(\g<ipv6partc>{3}\g<cipv6part>{1,3})
    |(\g<ipv6partc>{3}\g<cipv6part>{1,2}(:\g<ipv4>))
    |(\g<ipv6partc>{2}\g<cipv6part>{1,4})
    |(\g<ipv6partc>{2}\g<cipv6part>{1,3}(:\g<ipv4>))
    |(\g<ipv6partc>\g<cipv6part>{1,5})
    |(\g<ipv6partc>\g<cipv6part>{1,4}(:\g<ipv4>))
    |(:\g<cipv6part>{1,6})
    |(:\g<cipv6part>{1,4}(:\g<ipv4>))
    |(\g<ipv6partc>{1,6}:)
    |(\g<ipv6partc>{6}(\g<ipv4>))
    |(::)
    )\]))
)

(?(DEFINE)
  (?<host>(\g<hostname>|\g<ipv4>|\g<ipv6>))
)

(?(DEFINE)
  (?<port>:((6((5(5((3[0-5])|([0-2][0-9]))|([0-4][0-9]{2})))|([0-4][0-9]{3})))|([1-5][0-9]{4})|([1-9][0-9]{0,3})|0))
)

(?(DEFINE)
  (?<hostname>(([\p{L}\d]([\p{L}\d\-]*[\p{L}\d])?\.)+\p{L}([\p{L}\d-]*[\p{L}\d])?))
)

(?(DEFINE)
  (?<path>\/(\g<uchar>|\g<additional2>)*)
)

(?(DEFINE)
  (?<search>\?(\g<uchar>|\g<additional2>)*)
)

(?(DEFINE)
  (?<fragment>\#(\g<uchar>|\g<additional2>)+)
)

^\g<scheme>?\g<login>?\g<host>\g<port>?\g<path>*\g<search>?\g<fragment>?$

ENDTEXT

m.RX.Pattern = m.RxPattern

CLEAR

IF ! m.RX.Validate()

	? "-----------------------------"
	? "Error:", m.RX.RegExpErrorMessage
	? "Location:", m.RX.RegExpErrorLocation
	? "-----------------------------"

	RETURN

ENDIF

LOCAL TestHttpURL AS String

m.TestHttpURL = .NULL.

DO WHILE ! EMPTY(m.TestHttpURL)

	m.TestHttpURL = INPUTBOX("Insert an HTTP URL for testing:", "Test HTTP URL")

	IF ! EMPTY(m.TestHttpURL)
		? m.RX.Test(m.TestHttpURL), m.TestHttpURL
	ENDIF

ENDDO
