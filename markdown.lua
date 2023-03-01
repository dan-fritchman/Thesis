-- 
-- Copyright (C) 2009-2016 John MacFarlane, Hans Hagen
-- 
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- 
-- Copyright (C) 2016-2019 Vít Novotný
-- 
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
-- 
--     http://www.latex-project.org/lppl.txt
-- 
-- and version 1.3 or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
-- 
-- This work has the LPPL maintenance status `maintained'.
-- The Current Maintainer of this work is Vít Novotný.
-- 
-- Send bug reports, requests for additions and questions
-- either to the GitHub issue tracker at
-- 
--     https://github.com/witiko/markdown/issues
-- 
-- or to the e-mail address <witiko@mail.muni.cz>.
-- 
-- MODIFICATION ADVICE:
-- 
-- If you want to customize this file, it is best to make a copy of
-- the source file(s) from which it was produced. Use a different
-- name for your copy(ies) and modify the copy(ies); this will ensure
-- that your modifications do not get overwritten when you install a
-- new release of the standard system. You should also ensure that
-- your modified source file does not generate any modified file with
-- the same name as a standard file.
-- 
-- You will also need to produce your own, suitably named, .ins file to
-- control the generation of files from your source file; this file
-- should contain your own preambles for the files it generates, not
-- those in the standard .ins files.
-- 
local metadata = {
    version   = "2.8.1",
    comment   = "A module for the conversion from markdown to plain TeX",
    author    = "John MacFarlane, Hans Hagen, Vít Novotný",
    copyright = {"2009-2016 John MacFarlane, Hans Hagen",
                 "2016-2019 Vít Novotný"},
    license   = "LPPL 1.3"
}

if not modules then modules = { } end
modules['markdown'] = metadata
local lpeg = require("lpeg")
local unicode = require("unicode")
local md5 = require("md5")
local M = {metadata = metadata}
local defaultOptions = {}
defaultOptions.cacheDir = "."
defaultOptions.blankBeforeBlockquote = false
defaultOptions.blankBeforeCodeFence = false
defaultOptions.blankBeforeHeading = false
defaultOptions.breakableBlockquotes = false
defaultOptions.citationNbsps = true
defaultOptions.citations = false
defaultOptions.codeSpans = true
defaultOptions.contentBlocks = false
defaultOptions.contentBlocksLanguageMap = "markdown-languages.json"
defaultOptions.definitionLists = false
defaultOptions.fencedCode = false
defaultOptions.footnotes = false
defaultOptions.hashEnumerators = false
defaultOptions.headerAttributes = false
defaultOptions.html = false
defaultOptions.hybrid = false
defaultOptions.inlineFootnotes = false
defaultOptions.pipeTables = false
defaultOptions.preserveTabs = false
defaultOptions.shiftHeadings = 0
defaultOptions.slice = "^ $"
defaultOptions.smartEllipses = false
defaultOptions.startNumber = true
defaultOptions.tableCaptions = false
defaultOptions.tightLists = true
defaultOptions.underscores = true
local upper, gsub, format, length =
  string.upper, string.gsub, string.format, string.len
local concat = table.concat
local P, R, S, V, C, Cg, Cb, Cmt, Cc, Ct, B, Cs, any =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Ct, lpeg.B, lpeg.Cs, lpeg.P(1)
local util = {}
function util.err(msg, exit_code)
  io.stderr:write("markdown.lua: " .. msg .. "\n")
  os.exit(exit_code or 1)
end
function util.cache(dir, string, salt, transform, suffix)
  local digest = md5.sumhexa(string .. (salt or ""))
  local name = util.pathname(dir, digest .. suffix)
  local file = io.open(name, "r")
  if file == nil then -- If no cache entry exists, then create a new one.
    local file = assert(io.open(name, "w"))
    local result = string
    if transform ~= nil then
      result = transform(result)
    end
    assert(file:write(result))
    assert(file:close())
  end
  return name
end
function util.table_copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end
function util.expand_tabs_in_line(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (s:gsub("()\t", function(p)
            local sp = tab - (p - 1 + corr) % tab
            corr = corr - 1 + sp
            return string.rep(" ", sp)
          end))
end
function util.walk(t, f)
  local typ = type(t)
  if typ == "string" then
    f(t)
  elseif typ == "table" then
    local i = 1
    local n
    n = t[i]
    while n do
      util.walk(n, f)
      i = i + 1
      n = t[i]
    end
  elseif typ == "function" then
    local ok, val = pcall(t)
    if ok then
      util.walk(val,f)
    end
  else
    f(tostring(t))
  end
end
function util.flatten(ary)
  local new = {}
  for _,v in ipairs(ary) do
    if type(v) == "table" then
      for _,w in ipairs(util.flatten(v)) do
        new[#new + 1] = w
      end
    else
      new[#new + 1] = v
    end
  end
  return new
end
function util.rope_to_string(rope)
  local buffer = {}
  util.walk(rope, function(x) buffer[#buffer + 1] = x end)
  return table.concat(buffer)
end
function util.rope_last(rope)
  if #rope == 0 then
    return nil
  else
    local l = rope[#rope]
    if type(l) == "table" then
      return util.rope_last(l)
    else
      return l
    end
  end
end
function util.intersperse(ary, x)
  local new = {}
  local l = #ary
  for i,v in ipairs(ary) do
    local n = #new
    new[n + 1] = v
    if i ~= l then
      new[n + 2] = x
    end
  end
  return new
end
function util.map(ary, f)
  local new = {}
  for i,v in ipairs(ary) do
    new[i] = f(v)
  end
  return new
end
function util.escaper(char_escapes, string_escapes)
  local char_escapes_list = ""
  for i,_ in pairs(char_escapes) do
    char_escapes_list = char_escapes_list .. i
  end
  local escapable = S(char_escapes_list) / char_escapes
  if string_escapes then
    for k,v in pairs(string_escapes) do
      escapable = P(k) / v + escapable
    end
  end
  local escape_string = Cs((escapable + any)^0)
  return function(s)
    return lpeg.match(escape_string, s)
  end
end
function util.pathname(dir, file)
  if #dir == 0 then
    return file
  else
    return dir .. "/" .. file
  end
end
local entities = {}

local character_entities = {
  ["Tab"] = 9,
  ["NewLine"] = 10,
  ["excl"] = 33,
  ["quot"] = 34,
  ["QUOT"] = 34,
  ["num"] = 35,
  ["dollar"] = 36,
  ["percnt"] = 37,
  ["amp"] = 38,
  ["AMP"] = 38,
  ["apos"] = 39,
  ["lpar"] = 40,
  ["rpar"] = 41,
  ["ast"] = 42,
  ["midast"] = 42,
  ["plus"] = 43,
  ["comma"] = 44,
  ["period"] = 46,
  ["sol"] = 47,
  ["colon"] = 58,
  ["semi"] = 59,
  ["lt"] = 60,
  ["LT"] = 60,
  ["equals"] = 61,
  ["gt"] = 62,
  ["GT"] = 62,
  ["quest"] = 63,
  ["commat"] = 64,
  ["lsqb"] = 91,
  ["lbrack"] = 91,
  ["bsol"] = 92,
  ["rsqb"] = 93,
  ["rbrack"] = 93,
  ["Hat"] = 94,
  ["lowbar"] = 95,
  ["grave"] = 96,
  ["DiacriticalGrave"] = 96,
  ["lcub"] = 123,
  ["lbrace"] = 123,
  ["verbar"] = 124,
  ["vert"] = 124,
  ["VerticalLine"] = 124,
  ["rcub"] = 125,
  ["rbrace"] = 125,
  ["nbsp"] = 160,
  ["NonBreakingSpace"] = 160,
  ["iexcl"] = 161,
  ["cent"] = 162,
  ["pound"] = 163,
  ["curren"] = 164,
  ["yen"] = 165,
  ["brvbar"] = 166,
  ["sect"] = 167,
  ["Dot"] = 168,
  ["die"] = 168,
  ["DoubleDot"] = 168,
  ["uml"] = 168,
  ["copy"] = 169,
  ["COPY"] = 169,
  ["ordf"] = 170,
  ["laquo"] = 171,
  ["not"] = 172,
  ["shy"] = 173,
  ["reg"] = 174,
  ["circledR"] = 174,
  ["REG"] = 174,
  ["macr"] = 175,
  ["OverBar"] = 175,
  ["strns"] = 175,
  ["deg"] = 176,
  ["plusmn"] = 177,
  ["pm"] = 177,
  ["PlusMinus"] = 177,
  ["sup2"] = 178,
  ["sup3"] = 179,
  ["acute"] = 180,
  ["DiacriticalAcute"] = 180,
  ["micro"] = 181,
  ["para"] = 182,
  ["middot"] = 183,
  ["centerdot"] = 183,
  ["CenterDot"] = 183,
  ["cedil"] = 184,
  ["Cedilla"] = 184,
  ["sup1"] = 185,
  ["ordm"] = 186,
  ["raquo"] = 187,
  ["frac14"] = 188,
  ["frac12"] = 189,
  ["half"] = 189,
  ["frac34"] = 190,
  ["iquest"] = 191,
  ["Agrave"] = 192,
  ["Aacute"] = 193,
  ["Acirc"] = 194,
  ["Atilde"] = 195,
  ["Auml"] = 196,
  ["Aring"] = 197,
  ["AElig"] = 198,
  ["Ccedil"] = 199,
  ["Egrave"] = 200,
  ["Eacute"] = 201,
  ["Ecirc"] = 202,
  ["Euml"] = 203,
  ["Igrave"] = 204,
  ["Iacute"] = 205,
  ["Icirc"] = 206,
  ["Iuml"] = 207,
  ["ETH"] = 208,
  ["Ntilde"] = 209,
  ["Ograve"] = 210,
  ["Oacute"] = 211,
  ["Ocirc"] = 212,
  ["Otilde"] = 213,
  ["Ouml"] = 214,
  ["times"] = 215,
  ["Oslash"] = 216,
  ["Ugrave"] = 217,
  ["Uacute"] = 218,
  ["Ucirc"] = 219,
  ["Uuml"] = 220,
  ["Yacute"] = 221,
  ["THORN"] = 222,
  ["szlig"] = 223,
  ["agrave"] = 224,
  ["aacute"] = 225,
  ["acirc"] = 226,
  ["atilde"] = 227,
  ["auml"] = 228,
  ["aring"] = 229,
  ["aelig"] = 230,
  ["ccedil"] = 231,
  ["egrave"] = 232,
  ["eacute"] = 233,
  ["ecirc"] = 234,
  ["euml"] = 235,
  ["igrave"] = 236,
  ["iacute"] = 237,
  ["icirc"] = 238,
  ["iuml"] = 239,
  ["eth"] = 240,
  ["ntilde"] = 241,
  ["ograve"] = 242,
  ["oacute"] = 243,
  ["ocirc"] = 244,
  ["otilde"] = 245,
  ["ouml"] = 246,
  ["divide"] = 247,
  ["div"] = 247,
  ["oslash"] = 248,
  ["ugrave"] = 249,
  ["uacute"] = 250,
  ["ucirc"] = 251,
  ["uuml"] = 252,
  ["yacute"] = 253,
  ["thorn"] = 254,
  ["yuml"] = 255,
  ["Amacr"] = 256,
  ["amacr"] = 257,
  ["Abreve"] = 258,
  ["abreve"] = 259,
  ["Aogon"] = 260,
  ["aogon"] = 261,
  ["Cacute"] = 262,
  ["cacute"] = 263,
  ["Ccirc"] = 264,
  ["ccirc"] = 265,
  ["Cdot"] = 266,
  ["cdot"] = 267,
  ["Ccaron"] = 268,
  ["ccaron"] = 269,
  ["Dcaron"] = 270,
  ["dcaron"] = 271,
  ["Dstrok"] = 272,
  ["dstrok"] = 273,
  ["Emacr"] = 274,
  ["emacr"] = 275,
  ["Edot"] = 278,
  ["edot"] = 279,
  ["Eogon"] = 280,
  ["eogon"] = 281,
  ["Ecaron"] = 282,
  ["ecaron"] = 283,
  ["Gcirc"] = 284,
  ["gcirc"] = 285,
  ["Gbreve"] = 286,
  ["gbreve"] = 287,
  ["Gdot"] = 288,
  ["gdot"] = 289,
  ["Gcedil"] = 290,
  ["Hcirc"] = 292,
  ["hcirc"] = 293,
  ["Hstrok"] = 294,
  ["hstrok"] = 295,
  ["Itilde"] = 296,
  ["itilde"] = 297,
  ["Imacr"] = 298,
  ["imacr"] = 299,
  ["Iogon"] = 302,
  ["iogon"] = 303,
  ["Idot"] = 304,
  ["imath"] = 305,
  ["inodot"] = 305,
  ["IJlig"] = 306,
  ["ijlig"] = 307,
  ["Jcirc"] = 308,
  ["jcirc"] = 309,
  ["Kcedil"] = 310,
  ["kcedil"] = 311,
  ["kgreen"] = 312,
  ["Lacute"] = 313,
  ["lacute"] = 314,
  ["Lcedil"] = 315,
  ["lcedil"] = 316,
  ["Lcaron"] = 317,
  ["lcaron"] = 318,
  ["Lmidot"] = 319,
  ["lmidot"] = 320,
  ["Lstrok"] = 321,
  ["lstrok"] = 322,
  ["Nacute"] = 323,
  ["nacute"] = 324,
  ["Ncedil"] = 325,
  ["ncedil"] = 326,
  ["Ncaron"] = 327,
  ["ncaron"] = 328,
  ["napos"] = 329,
  ["ENG"] = 330,
  ["eng"] = 331,
  ["Omacr"] = 332,
  ["omacr"] = 333,
  ["Odblac"] = 336,
  ["odblac"] = 337,
  ["OElig"] = 338,
  ["oelig"] = 339,
  ["Racute"] = 340,
  ["racute"] = 341,
  ["Rcedil"] = 342,
  ["rcedil"] = 343,
  ["Rcaron"] = 344,
  ["rcaron"] = 345,
  ["Sacute"] = 346,
  ["sacute"] = 347,
  ["Scirc"] = 348,
  ["scirc"] = 349,
  ["Scedil"] = 350,
  ["scedil"] = 351,
  ["Scaron"] = 352,
  ["scaron"] = 353,
  ["Tcedil"] = 354,
  ["tcedil"] = 355,
  ["Tcaron"] = 356,
  ["tcaron"] = 357,
  ["Tstrok"] = 358,
  ["tstrok"] = 359,
  ["Utilde"] = 360,
  ["utilde"] = 361,
  ["Umacr"] = 362,
  ["umacr"] = 363,
  ["Ubreve"] = 364,
  ["ubreve"] = 365,
  ["Uring"] = 366,
  ["uring"] = 367,
  ["Udblac"] = 368,
  ["udblac"] = 369,
  ["Uogon"] = 370,
  ["uogon"] = 371,
  ["Wcirc"] = 372,
  ["wcirc"] = 373,
  ["Ycirc"] = 374,
  ["ycirc"] = 375,
  ["Yuml"] = 376,
  ["Zacute"] = 377,
  ["zacute"] = 378,
  ["Zdot"] = 379,
  ["zdot"] = 380,
  ["Zcaron"] = 381,
  ["zcaron"] = 382,
  ["fnof"] = 402,
  ["imped"] = 437,
  ["gacute"] = 501,
  ["jmath"] = 567,
  ["circ"] = 710,
  ["caron"] = 711,
  ["Hacek"] = 711,
  ["breve"] = 728,
  ["Breve"] = 728,
  ["dot"] = 729,
  ["DiacriticalDot"] = 729,
  ["ring"] = 730,
  ["ogon"] = 731,
  ["tilde"] = 732,
  ["DiacriticalTilde"] = 732,
  ["dblac"] = 733,
  ["DiacriticalDoubleAcute"] = 733,
  ["DownBreve"] = 785,
  ["UnderBar"] = 818,
  ["Alpha"] = 913,
  ["Beta"] = 914,
  ["Gamma"] = 915,
  ["Delta"] = 916,
  ["Epsilon"] = 917,
  ["Zeta"] = 918,
  ["Eta"] = 919,
  ["Theta"] = 920,
  ["Iota"] = 921,
  ["Kappa"] = 922,
  ["Lambda"] = 923,
  ["Mu"] = 924,
  ["Nu"] = 925,
  ["Xi"] = 926,
  ["Omicron"] = 927,
  ["Pi"] = 928,
  ["Rho"] = 929,
  ["Sigma"] = 931,
  ["Tau"] = 932,
  ["Upsilon"] = 933,
  ["Phi"] = 934,
  ["Chi"] = 935,
  ["Psi"] = 936,
  ["Omega"] = 937,
  ["alpha"] = 945,
  ["beta"] = 946,
  ["gamma"] = 947,
  ["delta"] = 948,
  ["epsiv"] = 949,
  ["varepsilon"] = 949,
  ["epsilon"] = 949,
  ["zeta"] = 950,
  ["eta"] = 951,
  ["theta"] = 952,
  ["iota"] = 953,
  ["kappa"] = 954,
  ["lambda"] = 955,
  ["mu"] = 956,
  ["nu"] = 957,
  ["xi"] = 958,
  ["omicron"] = 959,
  ["pi"] = 960,
  ["rho"] = 961,
  ["sigmav"] = 962,
  ["varsigma"] = 962,
  ["sigmaf"] = 962,
  ["sigma"] = 963,
  ["tau"] = 964,
  ["upsi"] = 965,
  ["upsilon"] = 965,
  ["phi"] = 966,
  ["phiv"] = 966,
  ["varphi"] = 966,
  ["chi"] = 967,
  ["psi"] = 968,
  ["omega"] = 969,
  ["thetav"] = 977,
  ["vartheta"] = 977,
  ["thetasym"] = 977,
  ["Upsi"] = 978,
  ["upsih"] = 978,
  ["straightphi"] = 981,
  ["piv"] = 982,
  ["varpi"] = 982,
  ["Gammad"] = 988,
  ["gammad"] = 989,
  ["digamma"] = 989,
  ["kappav"] = 1008,
  ["varkappa"] = 1008,
  ["rhov"] = 1009,
  ["varrho"] = 1009,
  ["epsi"] = 1013,
  ["straightepsilon"] = 1013,
  ["bepsi"] = 1014,
  ["backepsilon"] = 1014,
  ["IOcy"] = 1025,
  ["DJcy"] = 1026,
  ["GJcy"] = 1027,
  ["Jukcy"] = 1028,
  ["DScy"] = 1029,
  ["Iukcy"] = 1030,
  ["YIcy"] = 1031,
  ["Jsercy"] = 1032,
  ["LJcy"] = 1033,
  ["NJcy"] = 1034,
  ["TSHcy"] = 1035,
  ["KJcy"] = 1036,
  ["Ubrcy"] = 1038,
  ["DZcy"] = 1039,
  ["Acy"] = 1040,
  ["Bcy"] = 1041,
  ["Vcy"] = 1042,
  ["Gcy"] = 1043,
  ["Dcy"] = 1044,
  ["IEcy"] = 1045,
  ["ZHcy"] = 1046,
  ["Zcy"] = 1047,
  ["Icy"] = 1048,
  ["Jcy"] = 1049,
  ["Kcy"] = 1050,
  ["Lcy"] = 1051,
  ["Mcy"] = 1052,
  ["Ncy"] = 1053,
  ["Ocy"] = 1054,
  ["Pcy"] = 1055,
  ["Rcy"] = 1056,
  ["Scy"] = 1057,
  ["Tcy"] = 1058,
  ["Ucy"] = 1059,
  ["Fcy"] = 1060,
  ["KHcy"] = 1061,
  ["TScy"] = 1062,
  ["CHcy"] = 1063,
  ["SHcy"] = 1064,
  ["SHCHcy"] = 1065,
  ["HARDcy"] = 1066,
  ["Ycy"] = 1067,
  ["SOFTcy"] = 1068,
  ["Ecy"] = 1069,
  ["YUcy"] = 1070,
  ["YAcy"] = 1071,
  ["acy"] = 1072,
  ["bcy"] = 1073,
  ["vcy"] = 1074,
  ["gcy"] = 1075,
  ["dcy"] = 1076,
  ["iecy"] = 1077,
  ["zhcy"] = 1078,
  ["zcy"] = 1079,
  ["icy"] = 1080,
  ["jcy"] = 1081,
  ["kcy"] = 1082,
  ["lcy"] = 1083,
  ["mcy"] = 1084,
  ["ncy"] = 1085,
  ["ocy"] = 1086,
  ["pcy"] = 1087,
  ["rcy"] = 1088,
  ["scy"] = 1089,
  ["tcy"] = 1090,
  ["ucy"] = 1091,
  ["fcy"] = 1092,
  ["khcy"] = 1093,
  ["tscy"] = 1094,
  ["chcy"] = 1095,
  ["shcy"] = 1096,
  ["shchcy"] = 1097,
  ["hardcy"] = 1098,
  ["ycy"] = 1099,
  ["softcy"] = 1100,
  ["ecy"] = 1101,
  ["yucy"] = 1102,
  ["yacy"] = 1103,
  ["iocy"] = 1105,
  ["djcy"] = 1106,
  ["gjcy"] = 1107,
  ["jukcy"] = 1108,
  ["dscy"] = 1109,
  ["iukcy"] = 1110,
  ["yicy"] = 1111,
  ["jsercy"] = 1112,
  ["ljcy"] = 1113,
  ["njcy"] = 1114,
  ["tshcy"] = 1115,
  ["kjcy"] = 1116,
  ["ubrcy"] = 1118,
  ["dzcy"] = 1119,
  ["ensp"] = 8194,
  ["emsp"] = 8195,
  ["emsp13"] = 8196,
  ["emsp14"] = 8197,
  ["numsp"] = 8199,
  ["puncsp"] = 8200,
  ["thinsp"] = 8201,
  ["ThinSpace"] = 8201,
  ["hairsp"] = 8202,
  ["VeryThinSpace"] = 8202,
  ["ZeroWidthSpace"] = 8203,
  ["NegativeVeryThinSpace"] = 8203,
  ["NegativeThinSpace"] = 8203,
  ["NegativeMediumSpace"] = 8203,
  ["NegativeThickSpace"] = 8203,
  ["zwnj"] = 8204,
  ["zwj"] = 8205,
  ["lrm"] = 8206,
  ["rlm"] = 8207,
  ["hyphen"] = 8208,
  ["dash"] = 8208,
  ["ndash"] = 8211,
  ["mdash"] = 8212,
  ["horbar"] = 8213,
  ["Verbar"] = 8214,
  ["Vert"] = 8214,
  ["lsquo"] = 8216,
  ["OpenCurlyQuote"] = 8216,
  ["rsquo"] = 8217,
  ["rsquor"] = 8217,
  ["CloseCurlyQuote"] = 8217,
  ["lsquor"] = 8218,
  ["sbquo"] = 8218,
  ["ldquo"] = 8220,
  ["OpenCurlyDoubleQuote"] = 8220,
  ["rdquo"] = 8221,
  ["rdquor"] = 8221,
  ["CloseCurlyDoubleQuote"] = 8221,
  ["ldquor"] = 8222,
  ["bdquo"] = 8222,
  ["dagger"] = 8224,
  ["Dagger"] = 8225,
  ["ddagger"] = 8225,
  ["bull"] = 8226,
  ["bullet"] = 8226,
  ["nldr"] = 8229,
  ["hellip"] = 8230,
  ["mldr"] = 8230,
  ["permil"] = 8240,
  ["pertenk"] = 8241,
  ["prime"] = 8242,
  ["Prime"] = 8243,
  ["tprime"] = 8244,
  ["bprime"] = 8245,
  ["backprime"] = 8245,
  ["lsaquo"] = 8249,
  ["rsaquo"] = 8250,
  ["oline"] = 8254,
  ["caret"] = 8257,
  ["hybull"] = 8259,
  ["frasl"] = 8260,
  ["bsemi"] = 8271,
  ["qprime"] = 8279,
  ["MediumSpace"] = 8287,
  ["NoBreak"] = 8288,
  ["ApplyFunction"] = 8289,
  ["af"] = 8289,
  ["InvisibleTimes"] = 8290,
  ["it"] = 8290,
  ["InvisibleComma"] = 8291,
  ["ic"] = 8291,
  ["euro"] = 8364,
  ["tdot"] = 8411,
  ["TripleDot"] = 8411,
  ["DotDot"] = 8412,
  ["Copf"] = 8450,
  ["complexes"] = 8450,
  ["incare"] = 8453,
  ["gscr"] = 8458,
  ["hamilt"] = 8459,
  ["HilbertSpace"] = 8459,
  ["Hscr"] = 8459,
  ["Hfr"] = 8460,
  ["Poincareplane"] = 8460,
  ["quaternions"] = 8461,
  ["Hopf"] = 8461,
  ["planckh"] = 8462,
  ["planck"] = 8463,
  ["hbar"] = 8463,
  ["plankv"] = 8463,
  ["hslash"] = 8463,
  ["Iscr"] = 8464,
  ["imagline"] = 8464,
  ["image"] = 8465,
  ["Im"] = 8465,
  ["imagpart"] = 8465,
  ["Ifr"] = 8465,
  ["Lscr"] = 8466,
  ["lagran"] = 8466,
  ["Laplacetrf"] = 8466,
  ["ell"] = 8467,
  ["Nopf"] = 8469,
  ["naturals"] = 8469,
  ["numero"] = 8470,
  ["copysr"] = 8471,
  ["weierp"] = 8472,
  ["wp"] = 8472,
  ["Popf"] = 8473,
  ["primes"] = 8473,
  ["rationals"] = 8474,
  ["Qopf"] = 8474,
  ["Rscr"] = 8475,
  ["realine"] = 8475,
  ["real"] = 8476,
  ["Re"] = 8476,
  ["realpart"] = 8476,
  ["Rfr"] = 8476,
  ["reals"] = 8477,
  ["Ropf"] = 8477,
  ["rx"] = 8478,
  ["trade"] = 8482,
  ["TRADE"] = 8482,
  ["integers"] = 8484,
  ["Zopf"] = 8484,
  ["ohm"] = 8486,
  ["mho"] = 8487,
  ["Zfr"] = 8488,
  ["zeetrf"] = 8488,
  ["iiota"] = 8489,
  ["angst"] = 8491,
  ["bernou"] = 8492,
  ["Bernoullis"] = 8492,
  ["Bscr"] = 8492,
  ["Cfr"] = 8493,
  ["Cayleys"] = 8493,
  ["escr"] = 8495,
  ["Escr"] = 8496,
  ["expectation"] = 8496,
  ["Fscr"] = 8497,
  ["Fouriertrf"] = 8497,
  ["phmmat"] = 8499,
  ["Mellintrf"] = 8499,
  ["Mscr"] = 8499,
  ["order"] = 8500,
  ["orderof"] = 8500,
  ["oscr"] = 8500,
  ["alefsym"] = 8501,
  ["aleph"] = 8501,
  ["beth"] = 8502,
  ["gimel"] = 8503,
  ["daleth"] = 8504,
  ["CapitalDifferentialD"] = 8517,
  ["DD"] = 8517,
  ["DifferentialD"] = 8518,
  ["dd"] = 8518,
  ["ExponentialE"] = 8519,
  ["exponentiale"] = 8519,
  ["ee"] = 8519,
  ["ImaginaryI"] = 8520,
  ["ii"] = 8520,
  ["frac13"] = 8531,
  ["frac23"] = 8532,
  ["frac15"] = 8533,
  ["frac25"] = 8534,
  ["frac35"] = 8535,
  ["frac45"] = 8536,
  ["frac16"] = 8537,
  ["frac56"] = 8538,
  ["frac18"] = 8539,
  ["frac38"] = 8540,
  ["frac58"] = 8541,
  ["frac78"] = 8542,
  ["larr"] = 8592,
  ["leftarrow"] = 8592,
  ["LeftArrow"] = 8592,
  ["slarr"] = 8592,
  ["ShortLeftArrow"] = 8592,
  ["uarr"] = 8593,
  ["uparrow"] = 8593,
  ["UpArrow"] = 8593,
  ["ShortUpArrow"] = 8593,
  ["rarr"] = 8594,
  ["rightarrow"] = 8594,
  ["RightArrow"] = 8594,
  ["srarr"] = 8594,
  ["ShortRightArrow"] = 8594,
  ["darr"] = 8595,
  ["downarrow"] = 8595,
  ["DownArrow"] = 8595,
  ["ShortDownArrow"] = 8595,
  ["harr"] = 8596,
  ["leftrightarrow"] = 8596,
  ["LeftRightArrow"] = 8596,
  ["varr"] = 8597,
  ["updownarrow"] = 8597,
  ["UpDownArrow"] = 8597,
  ["nwarr"] = 8598,
  ["UpperLeftArrow"] = 8598,
  ["nwarrow"] = 8598,
  ["nearr"] = 8599,
  ["UpperRightArrow"] = 8599,
  ["nearrow"] = 8599,
  ["searr"] = 8600,
  ["searrow"] = 8600,
  ["LowerRightArrow"] = 8600,
  ["swarr"] = 8601,
  ["swarrow"] = 8601,
  ["LowerLeftArrow"] = 8601,
  ["nlarr"] = 8602,
  ["nleftarrow"] = 8602,
  ["nrarr"] = 8603,
  ["nrightarrow"] = 8603,
  ["rarrw"] = 8605,
  ["rightsquigarrow"] = 8605,
  ["Larr"] = 8606,
  ["twoheadleftarrow"] = 8606,
  ["Uarr"] = 8607,
  ["Rarr"] = 8608,
  ["twoheadrightarrow"] = 8608,
  ["Darr"] = 8609,
  ["larrtl"] = 8610,
  ["leftarrowtail"] = 8610,
  ["rarrtl"] = 8611,
  ["rightarrowtail"] = 8611,
  ["LeftTeeArrow"] = 8612,
  ["mapstoleft"] = 8612,
  ["UpTeeArrow"] = 8613,
  ["mapstoup"] = 8613,
  ["map"] = 8614,
  ["RightTeeArrow"] = 8614,
  ["mapsto"] = 8614,
  ["DownTeeArrow"] = 8615,
  ["mapstodown"] = 8615,
  ["larrhk"] = 8617,
  ["hookleftarrow"] = 8617,
  ["rarrhk"] = 8618,
  ["hookrightarrow"] = 8618,
  ["larrlp"] = 8619,
  ["looparrowleft"] = 8619,
  ["rarrlp"] = 8620,
  ["looparrowright"] = 8620,
  ["harrw"] = 8621,
  ["leftrightsquigarrow"] = 8621,
  ["nharr"] = 8622,
  ["nleftrightarrow"] = 8622,
  ["lsh"] = 8624,
  ["Lsh"] = 8624,
  ["rsh"] = 8625,
  ["Rsh"] = 8625,
  ["ldsh"] = 8626,
  ["rdsh"] = 8627,
  ["crarr"] = 8629,
  ["cularr"] = 8630,
  ["curvearrowleft"] = 8630,
  ["curarr"] = 8631,
  ["curvearrowright"] = 8631,
  ["olarr"] = 8634,
  ["circlearrowleft"] = 8634,
  ["orarr"] = 8635,
  ["circlearrowright"] = 8635,
  ["lharu"] = 8636,
  ["LeftVector"] = 8636,
  ["leftharpoonup"] = 8636,
  ["lhard"] = 8637,
  ["leftharpoondown"] = 8637,
  ["DownLeftVector"] = 8637,
  ["uharr"] = 8638,
  ["upharpoonright"] = 8638,
  ["RightUpVector"] = 8638,
  ["uharl"] = 8639,
  ["upharpoonleft"] = 8639,
  ["LeftUpVector"] = 8639,
  ["rharu"] = 8640,
  ["RightVector"] = 8640,
  ["rightharpoonup"] = 8640,
  ["rhard"] = 8641,
  ["rightharpoondown"] = 8641,
  ["DownRightVector"] = 8641,
  ["dharr"] = 8642,
  ["RightDownVector"] = 8642,
  ["downharpoonright"] = 8642,
  ["dharl"] = 8643,
  ["LeftDownVector"] = 8643,
  ["downharpoonleft"] = 8643,
  ["rlarr"] = 8644,
  ["rightleftarrows"] = 8644,
  ["RightArrowLeftArrow"] = 8644,
  ["udarr"] = 8645,
  ["UpArrowDownArrow"] = 8645,
  ["lrarr"] = 8646,
  ["leftrightarrows"] = 8646,
  ["LeftArrowRightArrow"] = 8646,
  ["llarr"] = 8647,
  ["leftleftarrows"] = 8647,
  ["uuarr"] = 8648,
  ["upuparrows"] = 8648,
  ["rrarr"] = 8649,
  ["rightrightarrows"] = 8649,
  ["ddarr"] = 8650,
  ["downdownarrows"] = 8650,
  ["lrhar"] = 8651,
  ["ReverseEquilibrium"] = 8651,
  ["leftrightharpoons"] = 8651,
  ["rlhar"] = 8652,
  ["rightleftharpoons"] = 8652,
  ["Equilibrium"] = 8652,
  ["nlArr"] = 8653,
  ["nLeftarrow"] = 8653,
  ["nhArr"] = 8654,
  ["nLeftrightarrow"] = 8654,
  ["nrArr"] = 8655,
  ["nRightarrow"] = 8655,
  ["lArr"] = 8656,
  ["Leftarrow"] = 8656,
  ["DoubleLeftArrow"] = 8656,
  ["uArr"] = 8657,
  ["Uparrow"] = 8657,
  ["DoubleUpArrow"] = 8657,
  ["rArr"] = 8658,
  ["Rightarrow"] = 8658,
  ["Implies"] = 8658,
  ["DoubleRightArrow"] = 8658,
  ["dArr"] = 8659,
  ["Downarrow"] = 8659,
  ["DoubleDownArrow"] = 8659,
  ["hArr"] = 8660,
  ["Leftrightarrow"] = 8660,
  ["DoubleLeftRightArrow"] = 8660,
  ["iff"] = 8660,
  ["vArr"] = 8661,
  ["Updownarrow"] = 8661,
  ["DoubleUpDownArrow"] = 8661,
  ["nwArr"] = 8662,
  ["neArr"] = 8663,
  ["seArr"] = 8664,
  ["swArr"] = 8665,
  ["lAarr"] = 8666,
  ["Lleftarrow"] = 8666,
  ["rAarr"] = 8667,
  ["Rrightarrow"] = 8667,
  ["zigrarr"] = 8669,
  ["larrb"] = 8676,
  ["LeftArrowBar"] = 8676,
  ["rarrb"] = 8677,
  ["RightArrowBar"] = 8677,
  ["duarr"] = 8693,
  ["DownArrowUpArrow"] = 8693,
  ["loarr"] = 8701,
  ["roarr"] = 8702,
  ["hoarr"] = 8703,
  ["forall"] = 8704,
  ["ForAll"] = 8704,
  ["comp"] = 8705,
  ["complement"] = 8705,
  ["part"] = 8706,
  ["PartialD"] = 8706,
  ["exist"] = 8707,
  ["Exists"] = 8707,
  ["nexist"] = 8708,
  ["NotExists"] = 8708,
  ["nexists"] = 8708,
  ["empty"] = 8709,
  ["emptyset"] = 8709,
  ["emptyv"] = 8709,
  ["varnothing"] = 8709,
  ["nabla"] = 8711,
  ["Del"] = 8711,
  ["isin"] = 8712,
  ["isinv"] = 8712,
  ["Element"] = 8712,
  ["in"] = 8712,
  ["notin"] = 8713,
  ["NotElement"] = 8713,
  ["notinva"] = 8713,
  ["niv"] = 8715,
  ["ReverseElement"] = 8715,
  ["ni"] = 8715,
  ["SuchThat"] = 8715,
  ["notni"] = 8716,
  ["notniva"] = 8716,
  ["NotReverseElement"] = 8716,
  ["prod"] = 8719,
  ["Product"] = 8719,
  ["coprod"] = 8720,
  ["Coproduct"] = 8720,
  ["sum"] = 8721,
  ["Sum"] = 8721,
  ["minus"] = 8722,
  ["mnplus"] = 8723,
  ["mp"] = 8723,
  ["MinusPlus"] = 8723,
  ["plusdo"] = 8724,
  ["dotplus"] = 8724,
  ["setmn"] = 8726,
  ["setminus"] = 8726,
  ["Backslash"] = 8726,
  ["ssetmn"] = 8726,
  ["smallsetminus"] = 8726,
  ["lowast"] = 8727,
  ["compfn"] = 8728,
  ["SmallCircle"] = 8728,
  ["radic"] = 8730,
  ["Sqrt"] = 8730,
  ["prop"] = 8733,
  ["propto"] = 8733,
  ["Proportional"] = 8733,
  ["vprop"] = 8733,
  ["varpropto"] = 8733,
  ["infin"] = 8734,
  ["angrt"] = 8735,
  ["ang"] = 8736,
  ["angle"] = 8736,
  ["angmsd"] = 8737,
  ["measuredangle"] = 8737,
  ["angsph"] = 8738,
  ["mid"] = 8739,
  ["VerticalBar"] = 8739,
  ["smid"] = 8739,
  ["shortmid"] = 8739,
  ["nmid"] = 8740,
  ["NotVerticalBar"] = 8740,
  ["nsmid"] = 8740,
  ["nshortmid"] = 8740,
  ["par"] = 8741,
  ["parallel"] = 8741,
  ["DoubleVerticalBar"] = 8741,
  ["spar"] = 8741,
  ["shortparallel"] = 8741,
  ["npar"] = 8742,
  ["nparallel"] = 8742,
  ["NotDoubleVerticalBar"] = 8742,
  ["nspar"] = 8742,
  ["nshortparallel"] = 8742,
  ["and"] = 8743,
  ["wedge"] = 8743,
  ["or"] = 8744,
  ["vee"] = 8744,
  ["cap"] = 8745,
  ["cup"] = 8746,
  ["int"] = 8747,
  ["Integral"] = 8747,
  ["Int"] = 8748,
  ["tint"] = 8749,
  ["iiint"] = 8749,
  ["conint"] = 8750,
  ["oint"] = 8750,
  ["ContourIntegral"] = 8750,
  ["Conint"] = 8751,
  ["DoubleContourIntegral"] = 8751,
  ["Cconint"] = 8752,
  ["cwint"] = 8753,
  ["cwconint"] = 8754,
  ["ClockwiseContourIntegral"] = 8754,
  ["awconint"] = 8755,
  ["CounterClockwiseContourIntegral"] = 8755,
  ["there4"] = 8756,
  ["therefore"] = 8756,
  ["Therefore"] = 8756,
  ["becaus"] = 8757,
  ["because"] = 8757,
  ["Because"] = 8757,
  ["ratio"] = 8758,
  ["Colon"] = 8759,
  ["Proportion"] = 8759,
  ["minusd"] = 8760,
  ["dotminus"] = 8760,
  ["mDDot"] = 8762,
  ["homtht"] = 8763,
  ["sim"] = 8764,
  ["Tilde"] = 8764,
  ["thksim"] = 8764,
  ["thicksim"] = 8764,
  ["bsim"] = 8765,
  ["backsim"] = 8765,
  ["ac"] = 8766,
  ["mstpos"] = 8766,
  ["acd"] = 8767,
  ["wreath"] = 8768,
  ["VerticalTilde"] = 8768,
  ["wr"] = 8768,
  ["nsim"] = 8769,
  ["NotTilde"] = 8769,
  ["esim"] = 8770,
  ["EqualTilde"] = 8770,
  ["eqsim"] = 8770,
  ["sime"] = 8771,
  ["TildeEqual"] = 8771,
  ["simeq"] = 8771,
  ["nsime"] = 8772,
  ["nsimeq"] = 8772,
  ["NotTildeEqual"] = 8772,
  ["cong"] = 8773,
  ["TildeFullEqual"] = 8773,
  ["simne"] = 8774,
  ["ncong"] = 8775,
  ["NotTildeFullEqual"] = 8775,
  ["asymp"] = 8776,
  ["ap"] = 8776,
  ["TildeTilde"] = 8776,
  ["approx"] = 8776,
  ["thkap"] = 8776,
  ["thickapprox"] = 8776,
  ["nap"] = 8777,
  ["NotTildeTilde"] = 8777,
  ["napprox"] = 8777,
  ["ape"] = 8778,
  ["approxeq"] = 8778,
  ["apid"] = 8779,
  ["bcong"] = 8780,
  ["backcong"] = 8780,
  ["asympeq"] = 8781,
  ["CupCap"] = 8781,
  ["bump"] = 8782,
  ["HumpDownHump"] = 8782,
  ["Bumpeq"] = 8782,
  ["bumpe"] = 8783,
  ["HumpEqual"] = 8783,
  ["bumpeq"] = 8783,
  ["esdot"] = 8784,
  ["DotEqual"] = 8784,
  ["doteq"] = 8784,
  ["eDot"] = 8785,
  ["doteqdot"] = 8785,
  ["efDot"] = 8786,
  ["fallingdotseq"] = 8786,
  ["erDot"] = 8787,
  ["risingdotseq"] = 8787,
  ["colone"] = 8788,
  ["coloneq"] = 8788,
  ["Assign"] = 8788,
  ["ecolon"] = 8789,
  ["eqcolon"] = 8789,
  ["ecir"] = 8790,
  ["eqcirc"] = 8790,
  ["cire"] = 8791,
  ["circeq"] = 8791,
  ["wedgeq"] = 8793,
  ["veeeq"] = 8794,
  ["trie"] = 8796,
  ["triangleq"] = 8796,
  ["equest"] = 8799,
  ["questeq"] = 8799,
  ["ne"] = 8800,
  ["NotEqual"] = 8800,
  ["equiv"] = 8801,
  ["Congruent"] = 8801,
  ["nequiv"] = 8802,
  ["NotCongruent"] = 8802,
  ["le"] = 8804,
  ["leq"] = 8804,
  ["ge"] = 8805,
  ["GreaterEqual"] = 8805,
  ["geq"] = 8805,
  ["lE"] = 8806,
  ["LessFullEqual"] = 8806,
  ["leqq"] = 8806,
  ["gE"] = 8807,
  ["GreaterFullEqual"] = 8807,
  ["geqq"] = 8807,
  ["lnE"] = 8808,
  ["lneqq"] = 8808,
  ["gnE"] = 8809,
  ["gneqq"] = 8809,
  ["Lt"] = 8810,
  ["NestedLessLess"] = 8810,
  ["ll"] = 8810,
  ["Gt"] = 8811,
  ["NestedGreaterGreater"] = 8811,
  ["gg"] = 8811,
  ["twixt"] = 8812,
  ["between"] = 8812,
  ["NotCupCap"] = 8813,
  ["nlt"] = 8814,
  ["NotLess"] = 8814,
  ["nless"] = 8814,
  ["ngt"] = 8815,
  ["NotGreater"] = 8815,
  ["ngtr"] = 8815,
  ["nle"] = 8816,
  ["NotLessEqual"] = 8816,
  ["nleq"] = 8816,
  ["nge"] = 8817,
  ["NotGreaterEqual"] = 8817,
  ["ngeq"] = 8817,
  ["lsim"] = 8818,
  ["LessTilde"] = 8818,
  ["lesssim"] = 8818,
  ["gsim"] = 8819,
  ["gtrsim"] = 8819,
  ["GreaterTilde"] = 8819,
  ["nlsim"] = 8820,
  ["NotLessTilde"] = 8820,
  ["ngsim"] = 8821,
  ["NotGreaterTilde"] = 8821,
  ["lg"] = 8822,
  ["lessgtr"] = 8822,
  ["LessGreater"] = 8822,
  ["gl"] = 8823,
  ["gtrless"] = 8823,
  ["GreaterLess"] = 8823,
  ["ntlg"] = 8824,
  ["NotLessGreater"] = 8824,
  ["ntgl"] = 8825,
  ["NotGreaterLess"] = 8825,
  ["pr"] = 8826,
  ["Precedes"] = 8826,
  ["prec"] = 8826,
  ["sc"] = 8827,
  ["Succeeds"] = 8827,
  ["succ"] = 8827,
  ["prcue"] = 8828,
  ["PrecedesSlantEqual"] = 8828,
  ["preccurlyeq"] = 8828,
  ["sccue"] = 8829,
  ["SucceedsSlantEqual"] = 8829,
  ["succcurlyeq"] = 8829,
  ["prsim"] = 8830,
  ["precsim"] = 8830,
  ["PrecedesTilde"] = 8830,
  ["scsim"] = 8831,
  ["succsim"] = 8831,
  ["SucceedsTilde"] = 8831,
  ["npr"] = 8832,
  ["nprec"] = 8832,
  ["NotPrecedes"] = 8832,
  ["nsc"] = 8833,
  ["nsucc"] = 8833,
  ["NotSucceeds"] = 8833,
  ["sub"] = 8834,
  ["subset"] = 8834,
  ["sup"] = 8835,
  ["supset"] = 8835,
  ["Superset"] = 8835,
  ["nsub"] = 8836,
  ["nsup"] = 8837,
  ["sube"] = 8838,
  ["SubsetEqual"] = 8838,
  ["subseteq"] = 8838,
  ["supe"] = 8839,
  ["supseteq"] = 8839,
  ["SupersetEqual"] = 8839,
  ["nsube"] = 8840,
  ["nsubseteq"] = 8840,
  ["NotSubsetEqual"] = 8840,
  ["nsupe"] = 8841,
  ["nsupseteq"] = 8841,
  ["NotSupersetEqual"] = 8841,
  ["subne"] = 8842,
  ["subsetneq"] = 8842,
  ["supne"] = 8843,
  ["supsetneq"] = 8843,
  ["cupdot"] = 8845,
  ["uplus"] = 8846,
  ["UnionPlus"] = 8846,
  ["sqsub"] = 8847,
  ["SquareSubset"] = 8847,
  ["sqsubset"] = 8847,
  ["sqsup"] = 8848,
  ["SquareSuperset"] = 8848,
  ["sqsupset"] = 8848,
  ["sqsube"] = 8849,
  ["SquareSubsetEqual"] = 8849,
  ["sqsubseteq"] = 8849,
  ["sqsupe"] = 8850,
  ["SquareSupersetEqual"] = 8850,
  ["sqsupseteq"] = 8850,
  ["sqcap"] = 8851,
  ["SquareIntersection"] = 8851,
  ["sqcup"] = 8852,
  ["SquareUnion"] = 8852,
  ["oplus"] = 8853,
  ["CirclePlus"] = 8853,
  ["ominus"] = 8854,
  ["CircleMinus"] = 8854,
  ["otimes"] = 8855,
  ["CircleTimes"] = 8855,
  ["osol"] = 8856,
  ["odot"] = 8857,
  ["CircleDot"] = 8857,
  ["ocir"] = 8858,
  ["circledcirc"] = 8858,
  ["oast"] = 8859,
  ["circledast"] = 8859,
  ["odash"] = 8861,
  ["circleddash"] = 8861,
  ["plusb"] = 8862,
  ["boxplus"] = 8862,
  ["minusb"] = 8863,
  ["boxminus"] = 8863,
  ["timesb"] = 8864,
  ["boxtimes"] = 8864,
  ["sdotb"] = 8865,
  ["dotsquare"] = 8865,
  ["vdash"] = 8866,
  ["RightTee"] = 8866,
  ["dashv"] = 8867,
  ["LeftTee"] = 8867,
  ["top"] = 8868,
  ["DownTee"] = 8868,
  ["bottom"] = 8869,
  ["bot"] = 8869,
  ["perp"] = 8869,
  ["UpTee"] = 8869,
  ["models"] = 8871,
  ["vDash"] = 8872,
  ["DoubleRightTee"] = 8872,
  ["Vdash"] = 8873,
  ["Vvdash"] = 8874,
  ["VDash"] = 8875,
  ["nvdash"] = 8876,
  ["nvDash"] = 8877,
  ["nVdash"] = 8878,
  ["nVDash"] = 8879,
  ["prurel"] = 8880,
  ["vltri"] = 8882,
  ["vartriangleleft"] = 8882,
  ["LeftTriangle"] = 8882,
  ["vrtri"] = 8883,
  ["vartriangleright"] = 8883,
  ["RightTriangle"] = 8883,
  ["ltrie"] = 8884,
  ["trianglelefteq"] = 8884,
  ["LeftTriangleEqual"] = 8884,
  ["rtrie"] = 8885,
  ["trianglerighteq"] = 8885,
  ["RightTriangleEqual"] = 8885,
  ["origof"] = 8886,
  ["imof"] = 8887,
  ["mumap"] = 8888,
  ["multimap"] = 8888,
  ["hercon"] = 8889,
  ["intcal"] = 8890,
  ["intercal"] = 8890,
  ["veebar"] = 8891,
  ["barvee"] = 8893,
  ["angrtvb"] = 8894,
  ["lrtri"] = 8895,
  ["xwedge"] = 8896,
  ["Wedge"] = 8896,
  ["bigwedge"] = 8896,
  ["xvee"] = 8897,
  ["Vee"] = 8897,
  ["bigvee"] = 8897,
  ["xcap"] = 8898,
  ["Intersection"] = 8898,
  ["bigcap"] = 8898,
  ["xcup"] = 8899,
  ["Union"] = 8899,
  ["bigcup"] = 8899,
  ["diam"] = 8900,
  ["diamond"] = 8900,
  ["Diamond"] = 8900,
  ["sdot"] = 8901,
  ["sstarf"] = 8902,
  ["Star"] = 8902,
  ["divonx"] = 8903,
  ["divideontimes"] = 8903,
  ["bowtie"] = 8904,
  ["ltimes"] = 8905,
  ["rtimes"] = 8906,
  ["lthree"] = 8907,
  ["leftthreetimes"] = 8907,
  ["rthree"] = 8908,
  ["rightthreetimes"] = 8908,
  ["bsime"] = 8909,
  ["backsimeq"] = 8909,
  ["cuvee"] = 8910,
  ["curlyvee"] = 8910,
  ["cuwed"] = 8911,
  ["curlywedge"] = 8911,
  ["Sub"] = 8912,
  ["Subset"] = 8912,
  ["Sup"] = 8913,
  ["Supset"] = 8913,
  ["Cap"] = 8914,
  ["Cup"] = 8915,
  ["fork"] = 8916,
  ["pitchfork"] = 8916,
  ["epar"] = 8917,
  ["ltdot"] = 8918,
  ["lessdot"] = 8918,
  ["gtdot"] = 8919,
  ["gtrdot"] = 8919,
  ["Ll"] = 8920,
  ["Gg"] = 8921,
  ["ggg"] = 8921,
  ["leg"] = 8922,
  ["LessEqualGreater"] = 8922,
  ["lesseqgtr"] = 8922,
  ["gel"] = 8923,
  ["gtreqless"] = 8923,
  ["GreaterEqualLess"] = 8923,
  ["cuepr"] = 8926,
  ["curlyeqprec"] = 8926,
  ["cuesc"] = 8927,
  ["curlyeqsucc"] = 8927,
  ["nprcue"] = 8928,
  ["NotPrecedesSlantEqual"] = 8928,
  ["nsccue"] = 8929,
  ["NotSucceedsSlantEqual"] = 8929,
  ["nsqsube"] = 8930,
  ["NotSquareSubsetEqual"] = 8930,
  ["nsqsupe"] = 8931,
  ["NotSquareSupersetEqual"] = 8931,
  ["lnsim"] = 8934,
  ["gnsim"] = 8935,
  ["prnsim"] = 8936,
  ["precnsim"] = 8936,
  ["scnsim"] = 8937,
  ["succnsim"] = 8937,
  ["nltri"] = 8938,
  ["ntriangleleft"] = 8938,
  ["NotLeftTriangle"] = 8938,
  ["nrtri"] = 8939,
  ["ntriangleright"] = 8939,
  ["NotRightTriangle"] = 8939,
  ["nltrie"] = 8940,
  ["ntrianglelefteq"] = 8940,
  ["NotLeftTriangleEqual"] = 8940,
  ["nrtrie"] = 8941,
  ["ntrianglerighteq"] = 8941,
  ["NotRightTriangleEqual"] = 8941,
  ["vellip"] = 8942,
  ["ctdot"] = 8943,
  ["utdot"] = 8944,
  ["dtdot"] = 8945,
  ["disin"] = 8946,
  ["isinsv"] = 8947,
  ["isins"] = 8948,
  ["isindot"] = 8949,
  ["notinvc"] = 8950,
  ["notinvb"] = 8951,
  ["isinE"] = 8953,
  ["nisd"] = 8954,
  ["xnis"] = 8955,
  ["nis"] = 8956,
  ["notnivc"] = 8957,
  ["notnivb"] = 8958,
  ["barwed"] = 8965,
  ["barwedge"] = 8965,
  ["Barwed"] = 8966,
  ["doublebarwedge"] = 8966,
  ["lceil"] = 8968,
  ["LeftCeiling"] = 8968,
  ["rceil"] = 8969,
  ["RightCeiling"] = 8969,
  ["lfloor"] = 8970,
  ["LeftFloor"] = 8970,
  ["rfloor"] = 8971,
  ["RightFloor"] = 8971,
  ["drcrop"] = 8972,
  ["dlcrop"] = 8973,
  ["urcrop"] = 8974,
  ["ulcrop"] = 8975,
  ["bnot"] = 8976,
  ["profline"] = 8978,
  ["profsurf"] = 8979,
  ["telrec"] = 8981,
  ["target"] = 8982,
  ["ulcorn"] = 8988,
  ["ulcorner"] = 8988,
  ["urcorn"] = 8989,
  ["urcorner"] = 8989,
  ["dlcorn"] = 8990,
  ["llcorner"] = 8990,
  ["drcorn"] = 8991,
  ["lrcorner"] = 8991,
  ["frown"] = 8994,
  ["sfrown"] = 8994,
  ["smile"] = 8995,
  ["ssmile"] = 8995,
  ["cylcty"] = 9005,
  ["profalar"] = 9006,
  ["topbot"] = 9014,
  ["ovbar"] = 9021,
  ["solbar"] = 9023,
  ["angzarr"] = 9084,
  ["lmoust"] = 9136,
  ["lmoustache"] = 9136,
  ["rmoust"] = 9137,
  ["rmoustache"] = 9137,
  ["tbrk"] = 9140,
  ["OverBracket"] = 9140,
  ["bbrk"] = 9141,
  ["UnderBracket"] = 9141,
  ["bbrktbrk"] = 9142,
  ["OverParenthesis"] = 9180,
  ["UnderParenthesis"] = 9181,
  ["OverBrace"] = 9182,
  ["UnderBrace"] = 9183,
  ["trpezium"] = 9186,
  ["elinters"] = 9191,
  ["blank"] = 9251,
  ["oS"] = 9416,
  ["circledS"] = 9416,
  ["boxh"] = 9472,
  ["HorizontalLine"] = 9472,
  ["boxv"] = 9474,
  ["boxdr"] = 9484,
  ["boxdl"] = 9488,
  ["boxur"] = 9492,
  ["boxul"] = 9496,
  ["boxvr"] = 9500,
  ["boxvl"] = 9508,
  ["boxhd"] = 9516,
  ["boxhu"] = 9524,
  ["boxvh"] = 9532,
  ["boxH"] = 9552,
  ["boxV"] = 9553,
  ["boxdR"] = 9554,
  ["boxDr"] = 9555,
  ["boxDR"] = 9556,
  ["boxdL"] = 9557,
  ["boxDl"] = 9558,
  ["boxDL"] = 9559,
  ["boxuR"] = 9560,
  ["boxUr"] = 9561,
  ["boxUR"] = 9562,
  ["boxuL"] = 9563,
  ["boxUl"] = 9564,
  ["boxUL"] = 9565,
  ["boxvR"] = 9566,
  ["boxVr"] = 9567,
  ["boxVR"] = 9568,
  ["boxvL"] = 9569,
  ["boxVl"] = 9570,
  ["boxVL"] = 9571,
  ["boxHd"] = 9572,
  ["boxhD"] = 9573,
  ["boxHD"] = 9574,
  ["boxHu"] = 9575,
  ["boxhU"] = 9576,
  ["boxHU"] = 9577,
  ["boxvH"] = 9578,
  ["boxVh"] = 9579,
  ["boxVH"] = 9580,
  ["uhblk"] = 9600,
  ["lhblk"] = 9604,
  ["block"] = 9608,
  ["blk14"] = 9617,
  ["blk12"] = 9618,
  ["blk34"] = 9619,
  ["squ"] = 9633,
  ["square"] = 9633,
  ["Square"] = 9633,
  ["squf"] = 9642,
  ["squarf"] = 9642,
  ["blacksquare"] = 9642,
  ["FilledVerySmallSquare"] = 9642,
  ["EmptyVerySmallSquare"] = 9643,
  ["rect"] = 9645,
  ["marker"] = 9646,
  ["fltns"] = 9649,
  ["xutri"] = 9651,
  ["bigtriangleup"] = 9651,
  ["utrif"] = 9652,
  ["blacktriangle"] = 9652,
  ["utri"] = 9653,
  ["triangle"] = 9653,
  ["rtrif"] = 9656,
  ["blacktriangleright"] = 9656,
  ["rtri"] = 9657,
  ["triangleright"] = 9657,
  ["xdtri"] = 9661,
  ["bigtriangledown"] = 9661,
  ["dtrif"] = 9662,
  ["blacktriangledown"] = 9662,
  ["dtri"] = 9663,
  ["triangledown"] = 9663,
  ["ltrif"] = 9666,
  ["blacktriangleleft"] = 9666,
  ["ltri"] = 9667,
  ["triangleleft"] = 9667,
  ["loz"] = 9674,
  ["lozenge"] = 9674,
  ["cir"] = 9675,
  ["tridot"] = 9708,
  ["xcirc"] = 9711,
  ["bigcirc"] = 9711,
  ["ultri"] = 9720,
  ["urtri"] = 9721,
  ["lltri"] = 9722,
  ["EmptySmallSquare"] = 9723,
  ["FilledSmallSquare"] = 9724,
  ["starf"] = 9733,
  ["bigstar"] = 9733,
  ["star"] = 9734,
  ["phone"] = 9742,
  ["female"] = 9792,
  ["male"] = 9794,
  ["spades"] = 9824,
  ["spadesuit"] = 9824,
  ["clubs"] = 9827,
  ["clubsuit"] = 9827,
  ["hearts"] = 9829,
  ["heartsuit"] = 9829,
  ["diams"] = 9830,
  ["diamondsuit"] = 9830,
  ["sung"] = 9834,
  ["flat"] = 9837,
  ["natur"] = 9838,
  ["natural"] = 9838,
  ["sharp"] = 9839,
  ["check"] = 10003,
  ["checkmark"] = 10003,
  ["cross"] = 10007,
  ["malt"] = 10016,
  ["maltese"] = 10016,
  ["sext"] = 10038,
  ["VerticalSeparator"] = 10072,
  ["lbbrk"] = 10098,
  ["rbbrk"] = 10099,
  ["lobrk"] = 10214,
  ["LeftDoubleBracket"] = 10214,
  ["robrk"] = 10215,
  ["RightDoubleBracket"] = 10215,
  ["lang"] = 10216,
  ["LeftAngleBracket"] = 10216,
  ["langle"] = 10216,
  ["rang"] = 10217,
  ["RightAngleBracket"] = 10217,
  ["rangle"] = 10217,
  ["Lang"] = 10218,
  ["Rang"] = 10219,
  ["loang"] = 10220,
  ["roang"] = 10221,
  ["xlarr"] = 10229,
  ["longleftarrow"] = 10229,
  ["LongLeftArrow"] = 10229,
  ["xrarr"] = 10230,
  ["longrightarrow"] = 10230,
  ["LongRightArrow"] = 10230,
  ["xharr"] = 10231,
  ["longleftrightarrow"] = 10231,
  ["LongLeftRightArrow"] = 10231,
  ["xlArr"] = 10232,
  ["Longleftarrow"] = 10232,
  ["DoubleLongLeftArrow"] = 10232,
  ["xrArr"] = 10233,
  ["Longrightarrow"] = 10233,
  ["DoubleLongRightArrow"] = 10233,
  ["xhArr"] = 10234,
  ["Longleftrightarrow"] = 10234,
  ["DoubleLongLeftRightArrow"] = 10234,
  ["xmap"] = 10236,
  ["longmapsto"] = 10236,
  ["dzigrarr"] = 10239,
  ["nvlArr"] = 10498,
  ["nvrArr"] = 10499,
  ["nvHarr"] = 10500,
  ["Map"] = 10501,
  ["lbarr"] = 10508,
  ["rbarr"] = 10509,
  ["bkarow"] = 10509,
  ["lBarr"] = 10510,
  ["rBarr"] = 10511,
  ["dbkarow"] = 10511,
  ["RBarr"] = 10512,
  ["drbkarow"] = 10512,
  ["DDotrahd"] = 10513,
  ["UpArrowBar"] = 10514,
  ["DownArrowBar"] = 10515,
  ["Rarrtl"] = 10518,
  ["latail"] = 10521,
  ["ratail"] = 10522,
  ["lAtail"] = 10523,
  ["rAtail"] = 10524,
  ["larrfs"] = 10525,
  ["rarrfs"] = 10526,
  ["larrbfs"] = 10527,
  ["rarrbfs"] = 10528,
  ["nwarhk"] = 10531,
  ["nearhk"] = 10532,
  ["searhk"] = 10533,
  ["hksearow"] = 10533,
  ["swarhk"] = 10534,
  ["hkswarow"] = 10534,
  ["nwnear"] = 10535,
  ["nesear"] = 10536,
  ["toea"] = 10536,
  ["seswar"] = 10537,
  ["tosa"] = 10537,
  ["swnwar"] = 10538,
  ["rarrc"] = 10547,
  ["cudarrr"] = 10549,
  ["ldca"] = 10550,
  ["rdca"] = 10551,
  ["cudarrl"] = 10552,
  ["larrpl"] = 10553,
  ["curarrm"] = 10556,
  ["cularrp"] = 10557,
  ["rarrpl"] = 10565,
  ["harrcir"] = 10568,
  ["Uarrocir"] = 10569,
  ["lurdshar"] = 10570,
  ["ldrushar"] = 10571,
  ["LeftRightVector"] = 10574,
  ["RightUpDownVector"] = 10575,
  ["DownLeftRightVector"] = 10576,
  ["LeftUpDownVector"] = 10577,
  ["LeftVectorBar"] = 10578,
  ["RightVectorBar"] = 10579,
  ["RightUpVectorBar"] = 10580,
  ["RightDownVectorBar"] = 10581,
  ["DownLeftVectorBar"] = 10582,
  ["DownRightVectorBar"] = 10583,
  ["LeftUpVectorBar"] = 10584,
  ["LeftDownVectorBar"] = 10585,
  ["LeftTeeVector"] = 10586,
  ["RightTeeVector"] = 10587,
  ["RightUpTeeVector"] = 10588,
  ["RightDownTeeVector"] = 10589,
  ["DownLeftTeeVector"] = 10590,
  ["DownRightTeeVector"] = 10591,
  ["LeftUpTeeVector"] = 10592,
  ["LeftDownTeeVector"] = 10593,
  ["lHar"] = 10594,
  ["uHar"] = 10595,
  ["rHar"] = 10596,
  ["dHar"] = 10597,
  ["luruhar"] = 10598,
  ["ldrdhar"] = 10599,
  ["ruluhar"] = 10600,
  ["rdldhar"] = 10601,
  ["lharul"] = 10602,
  ["llhard"] = 10603,
  ["rharul"] = 10604,
  ["lrhard"] = 10605,
  ["udhar"] = 10606,
  ["UpEquilibrium"] = 10606,
  ["duhar"] = 10607,
  ["ReverseUpEquilibrium"] = 10607,
  ["RoundImplies"] = 10608,
  ["erarr"] = 10609,
  ["simrarr"] = 10610,
  ["larrsim"] = 10611,
  ["rarrsim"] = 10612,
  ["rarrap"] = 10613,
  ["ltlarr"] = 10614,
  ["gtrarr"] = 10616,
  ["subrarr"] = 10617,
  ["suplarr"] = 10619,
  ["lfisht"] = 10620,
  ["rfisht"] = 10621,
  ["ufisht"] = 10622,
  ["dfisht"] = 10623,
  ["lopar"] = 10629,
  ["ropar"] = 10630,
  ["lbrke"] = 10635,
  ["rbrke"] = 10636,
  ["lbrkslu"] = 10637,
  ["rbrksld"] = 10638,
  ["lbrksld"] = 10639,
  ["rbrkslu"] = 10640,
  ["langd"] = 10641,
  ["rangd"] = 10642,
  ["lparlt"] = 10643,
  ["rpargt"] = 10644,
  ["gtlPar"] = 10645,
  ["ltrPar"] = 10646,
  ["vzigzag"] = 10650,
  ["vangrt"] = 10652,
  ["angrtvbd"] = 10653,
  ["ange"] = 10660,
  ["range"] = 10661,
  ["dwangle"] = 10662,
  ["uwangle"] = 10663,
  ["angmsdaa"] = 10664,
  ["angmsdab"] = 10665,
  ["angmsdac"] = 10666,
  ["angmsdad"] = 10667,
  ["angmsdae"] = 10668,
  ["angmsdaf"] = 10669,
  ["angmsdag"] = 10670,
  ["angmsdah"] = 10671,
  ["bemptyv"] = 10672,
  ["demptyv"] = 10673,
  ["cemptyv"] = 10674,
  ["raemptyv"] = 10675,
  ["laemptyv"] = 10676,
  ["ohbar"] = 10677,
  ["omid"] = 10678,
  ["opar"] = 10679,
  ["operp"] = 10681,
  ["olcross"] = 10683,
  ["odsold"] = 10684,
  ["olcir"] = 10686,
  ["ofcir"] = 10687,
  ["olt"] = 10688,
  ["ogt"] = 10689,
  ["cirscir"] = 10690,
  ["cirE"] = 10691,
  ["solb"] = 10692,
  ["bsolb"] = 10693,
  ["boxbox"] = 10697,
  ["trisb"] = 10701,
  ["rtriltri"] = 10702,
  ["LeftTriangleBar"] = 10703,
  ["RightTriangleBar"] = 10704,
  ["race"] = 10714,
  ["iinfin"] = 10716,
  ["infintie"] = 10717,
  ["nvinfin"] = 10718,
  ["eparsl"] = 10723,
  ["smeparsl"] = 10724,
  ["eqvparsl"] = 10725,
  ["lozf"] = 10731,
  ["blacklozenge"] = 10731,
  ["RuleDelayed"] = 10740,
  ["dsol"] = 10742,
  ["xodot"] = 10752,
  ["bigodot"] = 10752,
  ["xoplus"] = 10753,
  ["bigoplus"] = 10753,
  ["xotime"] = 10754,
  ["bigotimes"] = 10754,
  ["xuplus"] = 10756,
  ["biguplus"] = 10756,
  ["xsqcup"] = 10758,
  ["bigsqcup"] = 10758,
  ["qint"] = 10764,
  ["iiiint"] = 10764,
  ["fpartint"] = 10765,
  ["cirfnint"] = 10768,
  ["awint"] = 10769,
  ["rppolint"] = 10770,
  ["scpolint"] = 10771,
  ["npolint"] = 10772,
  ["pointint"] = 10773,
  ["quatint"] = 10774,
  ["intlarhk"] = 10775,
  ["pluscir"] = 10786,
  ["plusacir"] = 10787,
  ["simplus"] = 10788,
  ["plusdu"] = 10789,
  ["plussim"] = 10790,
  ["plustwo"] = 10791,
  ["mcomma"] = 10793,
  ["minusdu"] = 10794,
  ["loplus"] = 10797,
  ["roplus"] = 10798,
  ["Cross"] = 10799,
  ["timesd"] = 10800,
  ["timesbar"] = 10801,
  ["smashp"] = 10803,
  ["lotimes"] = 10804,
  ["rotimes"] = 10805,
  ["otimesas"] = 10806,
  ["Otimes"] = 10807,
  ["odiv"] = 10808,
  ["triplus"] = 10809,
  ["triminus"] = 10810,
  ["tritime"] = 10811,
  ["iprod"] = 10812,
  ["intprod"] = 10812,
  ["amalg"] = 10815,
  ["capdot"] = 10816,
  ["ncup"] = 10818,
  ["ncap"] = 10819,
  ["capand"] = 10820,
  ["cupor"] = 10821,
  ["cupcap"] = 10822,
  ["capcup"] = 10823,
  ["cupbrcap"] = 10824,
  ["capbrcup"] = 10825,
  ["cupcup"] = 10826,
  ["capcap"] = 10827,
  ["ccups"] = 10828,
  ["ccaps"] = 10829,
  ["ccupssm"] = 10832,
  ["And"] = 10835,
  ["Or"] = 10836,
  ["andand"] = 10837,
  ["oror"] = 10838,
  ["orslope"] = 10839,
  ["andslope"] = 10840,
  ["andv"] = 10842,
  ["orv"] = 10843,
  ["andd"] = 10844,
  ["ord"] = 10845,
  ["wedbar"] = 10847,
  ["sdote"] = 10854,
  ["simdot"] = 10858,
  ["congdot"] = 10861,
  ["easter"] = 10862,
  ["apacir"] = 10863,
  ["apE"] = 10864,
  ["eplus"] = 10865,
  ["pluse"] = 10866,
  ["Esim"] = 10867,
  ["Colone"] = 10868,
  ["Equal"] = 10869,
  ["eDDot"] = 10871,
  ["ddotseq"] = 10871,
  ["equivDD"] = 10872,
  ["ltcir"] = 10873,
  ["gtcir"] = 10874,
  ["ltquest"] = 10875,
  ["gtquest"] = 10876,
  ["les"] = 10877,
  ["LessSlantEqual"] = 10877,
  ["leqslant"] = 10877,
  ["ges"] = 10878,
  ["GreaterSlantEqual"] = 10878,
  ["geqslant"] = 10878,
  ["lesdot"] = 10879,
  ["gesdot"] = 10880,
  ["lesdoto"] = 10881,
  ["gesdoto"] = 10882,
  ["lesdotor"] = 10883,
  ["gesdotol"] = 10884,
  ["lap"] = 10885,
  ["lessapprox"] = 10885,
  ["gap"] = 10886,
  ["gtrapprox"] = 10886,
  ["lne"] = 10887,
  ["lneq"] = 10887,
  ["gne"] = 10888,
  ["gneq"] = 10888,
  ["lnap"] = 10889,
  ["lnapprox"] = 10889,
  ["gnap"] = 10890,
  ["gnapprox"] = 10890,
  ["lEg"] = 10891,
  ["lesseqqgtr"] = 10891,
  ["gEl"] = 10892,
  ["gtreqqless"] = 10892,
  ["lsime"] = 10893,
  ["gsime"] = 10894,
  ["lsimg"] = 10895,
  ["gsiml"] = 10896,
  ["lgE"] = 10897,
  ["glE"] = 10898,
  ["lesges"] = 10899,
  ["gesles"] = 10900,
  ["els"] = 10901,
  ["eqslantless"] = 10901,
  ["egs"] = 10902,
  ["eqslantgtr"] = 10902,
  ["elsdot"] = 10903,
  ["egsdot"] = 10904,
  ["el"] = 10905,
  ["eg"] = 10906,
  ["siml"] = 10909,
  ["simg"] = 10910,
  ["simlE"] = 10911,
  ["simgE"] = 10912,
  ["LessLess"] = 10913,
  ["GreaterGreater"] = 10914,
  ["glj"] = 10916,
  ["gla"] = 10917,
  ["ltcc"] = 10918,
  ["gtcc"] = 10919,
  ["lescc"] = 10920,
  ["gescc"] = 10921,
  ["smt"] = 10922,
  ["lat"] = 10923,
  ["smte"] = 10924,
  ["late"] = 10925,
  ["bumpE"] = 10926,
  ["pre"] = 10927,
  ["preceq"] = 10927,
  ["PrecedesEqual"] = 10927,
  ["sce"] = 10928,
  ["succeq"] = 10928,
  ["SucceedsEqual"] = 10928,
  ["prE"] = 10931,
  ["scE"] = 10932,
  ["prnE"] = 10933,
  ["precneqq"] = 10933,
  ["scnE"] = 10934,
  ["succneqq"] = 10934,
  ["prap"] = 10935,
  ["precapprox"] = 10935,
  ["scap"] = 10936,
  ["succapprox"] = 10936,
  ["prnap"] = 10937,
  ["precnapprox"] = 10937,
  ["scnap"] = 10938,
  ["succnapprox"] = 10938,
  ["Pr"] = 10939,
  ["Sc"] = 10940,
  ["subdot"] = 10941,
  ["supdot"] = 10942,
  ["subplus"] = 10943,
  ["supplus"] = 10944,
  ["submult"] = 10945,
  ["supmult"] = 10946,
  ["subedot"] = 10947,
  ["supedot"] = 10948,
  ["subE"] = 10949,
  ["subseteqq"] = 10949,
  ["supE"] = 10950,
  ["supseteqq"] = 10950,
  ["subsim"] = 10951,
  ["supsim"] = 10952,
  ["subnE"] = 10955,
  ["subsetneqq"] = 10955,
  ["supnE"] = 10956,
  ["supsetneqq"] = 10956,
  ["csub"] = 10959,
  ["csup"] = 10960,
  ["csube"] = 10961,
  ["csupe"] = 10962,
  ["subsup"] = 10963,
  ["supsub"] = 10964,
  ["subsub"] = 10965,
  ["supsup"] = 10966,
  ["suphsub"] = 10967,
  ["supdsub"] = 10968,
  ["forkv"] = 10969,
  ["topfork"] = 10970,
  ["mlcp"] = 10971,
  ["Dashv"] = 10980,
  ["DoubleLeftTee"] = 10980,
  ["Vdashl"] = 10982,
  ["Barv"] = 10983,
  ["vBar"] = 10984,
  ["vBarv"] = 10985,
  ["Vbar"] = 10987,
  ["Not"] = 10988,
  ["bNot"] = 10989,
  ["rnmid"] = 10990,
  ["cirmid"] = 10991,
  ["midcir"] = 10992,
  ["topcir"] = 10993,
  ["nhpar"] = 10994,
  ["parsim"] = 10995,
  ["parsl"] = 11005,
  ["fflig"] = 64256,
  ["filig"] = 64257,
  ["fllig"] = 64258,
  ["ffilig"] = 64259,
  ["ffllig"] = 64260,
  ["Ascr"] = 119964,
  ["Cscr"] = 119966,
  ["Dscr"] = 119967,
  ["Gscr"] = 119970,
  ["Jscr"] = 119973,
  ["Kscr"] = 119974,
  ["Nscr"] = 119977,
  ["Oscr"] = 119978,
  ["Pscr"] = 119979,
  ["Qscr"] = 119980,
  ["Sscr"] = 119982,
  ["Tscr"] = 119983,
  ["Uscr"] = 119984,
  ["Vscr"] = 119985,
  ["Wscr"] = 119986,
  ["Xscr"] = 119987,
  ["Yscr"] = 119988,
  ["Zscr"] = 119989,
  ["ascr"] = 119990,
  ["bscr"] = 119991,
  ["cscr"] = 119992,
  ["dscr"] = 119993,
  ["fscr"] = 119995,
  ["hscr"] = 119997,
  ["iscr"] = 119998,
  ["jscr"] = 119999,
  ["kscr"] = 120000,
  ["lscr"] = 120001,
  ["mscr"] = 120002,
  ["nscr"] = 120003,
  ["pscr"] = 120005,
  ["qscr"] = 120006,
  ["rscr"] = 120007,
  ["sscr"] = 120008,
  ["tscr"] = 120009,
  ["uscr"] = 120010,
  ["vscr"] = 120011,
  ["wscr"] = 120012,
  ["xscr"] = 120013,
  ["yscr"] = 120014,
  ["zscr"] = 120015,
  ["Afr"] = 120068,
  ["Bfr"] = 120069,
  ["Dfr"] = 120071,
  ["Efr"] = 120072,
  ["Ffr"] = 120073,
  ["Gfr"] = 120074,
  ["Jfr"] = 120077,
  ["Kfr"] = 120078,
  ["Lfr"] = 120079,
  ["Mfr"] = 120080,
  ["Nfr"] = 120081,
  ["Ofr"] = 120082,
  ["Pfr"] = 120083,
  ["Qfr"] = 120084,
  ["Sfr"] = 120086,
  ["Tfr"] = 120087,
  ["Ufr"] = 120088,
  ["Vfr"] = 120089,
  ["Wfr"] = 120090,
  ["Xfr"] = 120091,
  ["Yfr"] = 120092,
  ["afr"] = 120094,
  ["bfr"] = 120095,
  ["cfr"] = 120096,
  ["dfr"] = 120097,
  ["efr"] = 120098,
  ["ffr"] = 120099,
  ["gfr"] = 120100,
  ["hfr"] = 120101,
  ["ifr"] = 120102,
  ["jfr"] = 120103,
  ["kfr"] = 120104,
  ["lfr"] = 120105,
  ["mfr"] = 120106,
  ["nfr"] = 120107,
  ["ofr"] = 120108,
  ["pfr"] = 120109,
  ["qfr"] = 120110,
  ["rfr"] = 120111,
  ["sfr"] = 120112,
  ["tfr"] = 120113,
  ["ufr"] = 120114,
  ["vfr"] = 120115,
  ["wfr"] = 120116,
  ["xfr"] = 120117,
  ["yfr"] = 120118,
  ["zfr"] = 120119,
  ["Aopf"] = 120120,
  ["Bopf"] = 120121,
  ["Dopf"] = 120123,
  ["Eopf"] = 120124,
  ["Fopf"] = 120125,
  ["Gopf"] = 120126,
  ["Iopf"] = 120128,
  ["Jopf"] = 120129,
  ["Kopf"] = 120130,
  ["Lopf"] = 120131,
  ["Mopf"] = 120132,
  ["Oopf"] = 120134,
  ["Sopf"] = 120138,
  ["Topf"] = 120139,
  ["Uopf"] = 120140,
  ["Vopf"] = 120141,
  ["Wopf"] = 120142,
  ["Xopf"] = 120143,
  ["Yopf"] = 120144,
  ["aopf"] = 120146,
  ["bopf"] = 120147,
  ["copf"] = 120148,
  ["dopf"] = 120149,
  ["eopf"] = 120150,
  ["fopf"] = 120151,
  ["gopf"] = 120152,
  ["hopf"] = 120153,
  ["iopf"] = 120154,
  ["jopf"] = 120155,
  ["kopf"] = 120156,
  ["lopf"] = 120157,
  ["mopf"] = 120158,
  ["nopf"] = 120159,
  ["oopf"] = 120160,
  ["popf"] = 120161,
  ["qopf"] = 120162,
  ["ropf"] = 120163,
  ["sopf"] = 120164,
  ["topf"] = 120165,
  ["uopf"] = 120166,
  ["vopf"] = 120167,
  ["wopf"] = 120168,
  ["xopf"] = 120169,
  ["yopf"] = 120170,
  ["zopf"] = 120171,
}
function entities.dec_entity(s)
  return unicode.utf8.char(tonumber(s))
end
function entities.hex_entity(s)
  return unicode.utf8.char(tonumber("0x"..s))
end
function entities.char_entity(s)
  local n = character_entities[s]
  if n == nil then
    return "&" .. s .. ";"
  end
  return unicode.utf8.char(n)
end
M.writer = {}
function M.writer.new(options)
  local self = {}
  options = options or {}
  setmetatable(options, { __index = function (_, key)
    return defaultOptions[key] end })
  local slice_specifiers = {}
  for specifier in options.slice:gmatch("[^%s]+") do
    table.insert(slice_specifiers, specifier)
  end

  if #slice_specifiers == 2 then
    self.slice_begin, self.slice_end = table.unpack(slice_specifiers)
    local slice_begin_type = self.slice_begin:sub(1, 1)
    if slice_begin_type ~= "^" and slice_begin_type ~= "$" then
      self.slice_begin = "^" .. self.slice_begin
    end
    local slice_end_type = self.slice_end:sub(1, 1)
    if slice_end_type ~= "^" and slice_end_type ~= "$" then
      self.slice_end = "$" .. self.slice_end
    end
  elseif #slice_specifiers == 1 then
    self.slice_begin = "^" .. slice_specifiers[1]
    self.slice_end = "$" .. slice_specifiers[1]
  end

  if self.slice_begin == "^" and self.slice_end ~= "^" then
    self.is_writing = true
  else
    self.is_writing = false
  end
  self.suffix = ".tex"
  self.space = " "
  self.nbsp = "\\markdownRendererNbsp{}"
  function self.plain(s)
    return s
  end
  function self.paragraph(s)
    if not self.is_writing then return "" end
    return s
  end
  function self.pack(name)
    return [[\input ]] .. name .. [[\relax{}]]
  end
  function self.interblocksep()
    if not self.is_writing then return "" end
    return "\\markdownRendererInterblockSeparator\n{}"
  end
  self.eof = [[\relax]]
  self.linebreak = "\\markdownRendererLineBreak\n{}"
  self.ellipsis = "\\markdownRendererEllipsis{}"
  function self.hrule()
    if not self.is_writing then return "" end
    return "\\markdownRendererHorizontalRule{}"
  end
  local escaped_chars = {
     ["{"] = "\\markdownRendererLeftBrace{}",
     ["}"] = "\\markdownRendererRightBrace{}",
     ["$"] = "\\markdownRendererDollarSign{}",
     ["%"] = "\\markdownRendererPercentSign{}",
     ["&"] = "\\markdownRendererAmpersand{}",
     ["_"] = "\\markdownRendererUnderscore{}",
     ["#"] = "\\markdownRendererHash{}",
     ["^"] = "\\markdownRendererCircumflex{}",
     ["\\"] = "\\markdownRendererBackslash{}",
     ["~"] = "\\markdownRendererTilde{}",
     ["|"] = "\\markdownRendererPipe{}",
   }
   local escaped_uri_chars = {
     ["{"] = "\\markdownRendererLeftBrace{}",
     ["}"] = "\\markdownRendererRightBrace{}",
     ["%"] = "\\markdownRendererPercentSign{}",
     ["\\"] = "\\markdownRendererBackslash{}",
   }
   local escaped_citation_chars = {
     ["{"] = "\\markdownRendererLeftBrace{}",
     ["}"] = "\\markdownRendererRightBrace{}",
     ["%"] = "\\markdownRendererPercentSign{}",
     ["#"] = "\\markdownRendererHash{}",
     ["\\"] = "\\markdownRendererBackslash{}",
   }
   local escaped_minimal_strings = {
     ["^^"] = "\\markdownRendererCircumflex\\markdownRendererCircumflex ",
   }
  local escape = util.escaper(escaped_chars)
  local escape_citation = util.escaper(escaped_citation_chars,
    escaped_minimal_strings)
  local escape_uri = util.escaper(escaped_uri_chars, escaped_minimal_strings)
  if options.hybrid then
    self.string = function(s) return s end
    self.citation = function(c) return c end
    self.uri = function(u) return u end
  else
    self.string = escape
    self.citation = escape_citation
    self.uri = escape_uri
  end
  function self.code(s)
    return {"\\markdownRendererCodeSpan{",escape(s),"}"}
  end
  function self.link(lab,src,tit)
    return {"\\markdownRendererLink{",lab,"}",
                          "{",self.string(src),"}",
                          "{",self.uri(src),"}",
                          "{",self.string(tit or ""),"}"}
  end
  function self.table(rows, caption)
    local buffer = {"\\markdownRendererTable{",
      caption or "", "}{", #rows - 1, "}{", #rows[1], "}"}
    local temp = rows[2] -- put alignments on the first row
    rows[2] = rows[1]
    rows[1] = temp
    for i, row in ipairs(rows) do
      table.insert(buffer, "{")
      for _, column in ipairs(row) do
        if i > 1 then -- do not use braces for alignments
          table.insert(buffer, "{")
        end
        table.insert(buffer, column)
        if i > 1 then
          table.insert(buffer, "}%\n")
        end
      end
      table.insert(buffer, "}%\n")
    end
    return buffer
  end
  function self.image(lab,src,tit)
    return {"\\markdownRendererImage{",lab,"}",
                           "{",self.string(src),"}",
                           "{",self.uri(src),"}",
                           "{",self.string(tit or ""),"}"}
  end
  local languages_json = (function()
    local kpse = require("kpse")
    kpse.set_program_name("luatex")
    local base, prev, curr
    for _, file in ipairs{kpse.lookup(options.contentBlocksLanguageMap,
                                      { all=true })} do
      json = io.open(file, "r"):read("*all")
                               :gsub('("[^\n]-"):','[%1]=')
      curr = (function()
        local _ENV={ json=json, load=load } -- run in sandbox
        return load("return "..json)()
      end)()
      if type(curr) == "table" then
        if base == nil then
          base = curr
        else
          setmetatable(prev, { __index = curr })
        end
        prev = curr
      end
    end
    return base or {}
  end)()
  function self.contentblock(src,suf,type,tit)
    if not self.is_writing then return "" end
    src = src.."."..suf
    suf = suf:lower()
    if type == "onlineimage" then
      return {"\\markdownRendererContentBlockOnlineImage{",suf,"}",
                             "{",self.string(src),"}",
                             "{",self.uri(src),"}",
                             "{",self.string(tit or ""),"}"}
    elseif languages_json[suf] then
      return {"\\markdownRendererContentBlockCode{",suf,"}",
                             "{",self.string(languages_json[suf]),"}",
                             "{",self.string(src),"}",
                             "{",self.uri(src),"}",
                             "{",self.string(tit or ""),"}"}
    else
      return {"\\markdownRendererContentBlock{",suf,"}",
                             "{",self.string(src),"}",
                             "{",self.uri(src),"}",
                             "{",self.string(tit or ""),"}"}
    end
  end
  local function ulitem(s)
    return {"\\markdownRendererUlItem ",s,
            "\\markdownRendererUlItemEnd "}
  end

  function self.bulletlist(items,tight)
    if not self.is_writing then return "" end
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = ulitem(item)
    end
    local contents = util.intersperse(buffer,"\n")
    if tight and options.tightLists then
      return {"\\markdownRendererUlBeginTight\n",contents,
        "\n\\markdownRendererUlEndTight "}
    else
      return {"\\markdownRendererUlBegin\n",contents,
        "\n\\markdownRendererUlEnd "}
    end
  end
  local function olitem(s,num)
    if num ~= nil then
      return {"\\markdownRendererOlItemWithNumber{",num,"}",s,
              "\\markdownRendererOlItemEnd "}
    else
      return {"\\markdownRendererOlItem ",s,
              "\\markdownRendererOlItemEnd "}
    end
  end

  function self.orderedlist(items,tight,startnum)
    if not self.is_writing then return "" end
    local buffer = {}
    local num = startnum
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = olitem(item,num)
      if num ~= nil then
        num = num + 1
      end
    end
    local contents = util.intersperse(buffer,"\n")
    if tight and options.tightLists then
      return {"\\markdownRendererOlBeginTight\n",contents,
        "\n\\markdownRendererOlEndTight "}
    else
      return {"\\markdownRendererOlBegin\n",contents,
        "\n\\markdownRendererOlEnd "}
    end
  end
  function self.inline_html(html)  return "" end
  function self.display_html(html) return "" end
  local function dlitem(term, defs)
    local retVal = {"\\markdownRendererDlItem{",term,"}"}
    for _, def in ipairs(defs) do
      retVal[#retVal+1] = {"\\markdownRendererDlDefinitionBegin ",def,
                           "\\markdownRendererDlDefinitionEnd "}
    end
    retVal[#retVal+1] = "\\markdownRendererDlItemEnd "
    return retVal
  end

  function self.definitionlist(items,tight)
    if not self.is_writing then return "" end
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = dlitem(item.term, item.definitions)
    end
    if tight and options.tightLists then
      return {"\\markdownRendererDlBeginTight\n", buffer,
        "\n\\markdownRendererDlEndTight"}
    else
      return {"\\markdownRendererDlBegin\n", buffer,
        "\n\\markdownRendererDlEnd"}
    end
  end
  function self.emphasis(s)
    return {"\\markdownRendererEmphasis{",s,"}"}
  end
  function self.strong(s)
    return {"\\markdownRendererStrongEmphasis{",s,"}"}
  end
  function self.blockquote(s)
    if #util.rope_to_string(s) == 0 then return "" end
    return {"\\markdownRendererBlockQuoteBegin\n",s,
      "\n\\markdownRendererBlockQuoteEnd "}
  end
  function self.verbatim(s)
    if not self.is_writing then return "" end
    local name = util.cache(options.cacheDir, s, nil, nil, ".verbatim")
    return {"\\markdownRendererInputVerbatim{",name,"}"}
  end
  function self.fencedCode(i, s)
    if not self.is_writing then return "" end
    local name = util.cache(options.cacheDir, s, nil, nil, ".verbatim")
    return {"\\markdownRendererInputFencedCode{",name,"}{",i,"}"}
  end
  self.active_headings = {}
  function self.heading(s,level,attributes)
    local active_headings = self.active_headings
    local slice_begin_type = self.slice_begin:sub(1, 1)
    local slice_begin_identifier = self.slice_begin:sub(2) or ""
    local slice_end_type = self.slice_end:sub(1, 1)
    local slice_end_identifier = self.slice_end:sub(2) or ""

    while #active_headings < level do
      -- push empty identifiers for implied sections
      table.insert(active_headings, {})
    end

    while #active_headings >= level do
      -- pop identifiers for sections that have ended
      local active_identifiers = active_headings[#active_headings]
      if active_identifiers[slice_begin_identifier] ~= nil
          and slice_begin_type == "$" then
        self.is_writing = true
      end
      if active_identifiers[slice_end_identifier] ~= nil
          and slice_end_type == "$" then
        self.is_writing = false
      end
      table.remove(active_headings, #active_headings)
    end

    -- push identifiers for the new section
    attributes = attributes or {}
    local identifiers = {}
    for index = 1, #attributes do
      attribute = attributes[index]
      identifiers[attribute:sub(2)] = true
    end
    if identifiers[slice_begin_identifier] ~= nil
        and slice_begin_type == "^" then
      self.is_writing = true
    end
    if identifiers[slice_end_identifier] ~= nil
        and slice_end_type == "^" then
      self.is_writing = false
    end
    table.insert(active_headings, identifiers)

    if not self.is_writing then return "" end

    local cmd
    level = level + options.shiftHeadings
    if level <= 1 then
      cmd = "\\markdownRendererHeadingOne"
    elseif level == 2 then
      cmd = "\\markdownRendererHeadingTwo"
    elseif level == 3 then
      cmd = "\\markdownRendererHeadingThree"
    elseif level == 4 then
      cmd = "\\markdownRendererHeadingFour"
    elseif level == 5 then
      cmd = "\\markdownRendererHeadingFive"
    elseif level >= 6 then
      cmd = "\\markdownRendererHeadingSix"
    else
      cmd = ""
    end
    return {cmd,"{",s,"}"}
  end
  function self.note(s)
    return {"\\markdownRendererFootnote{",s,"}"}
  end
  function self.citations(text_cites, cites)
    local buffer = {"\\markdownRenderer", text_cites and "TextCite" or "Cite",
      "{", #cites, "}"}
    for _,cite in ipairs(cites) do
      buffer[#buffer+1] = {cite.suppress_author and "-" or "+", "{",
        cite.prenote or "", "}{", cite.postnote or "", "}{", cite.name, "}"}
    end
    return buffer
  end

  return self
end
local parsers                  = {}
parsers.percent                = P("%")
parsers.at                     = P("@")
parsers.comma                  = P(",")
parsers.asterisk               = P("*")
parsers.dash                   = P("-")
parsers.plus                   = P("+")
parsers.underscore             = P("_")
parsers.period                 = P(".")
parsers.hash                   = P("#")
parsers.ampersand              = P("&")
parsers.backtick               = P("`")
parsers.less                   = P("<")
parsers.more                   = P(">")
parsers.space                  = P(" ")
parsers.squote                 = P("'")
parsers.dquote                 = P('"')
parsers.lparent                = P("(")
parsers.rparent                = P(")")
parsers.lbracket               = P("[")
parsers.rbracket               = P("]")
parsers.lbrace                 = P("{")
parsers.rbrace                 = P("}")
parsers.circumflex             = P("^")
parsers.slash                  = P("/")
parsers.equal                  = P("=")
parsers.colon                  = P(":")
parsers.semicolon              = P(";")
parsers.exclamation            = P("!")
parsers.pipe                   = P("|")
parsers.tilde                  = P("~")
parsers.tab                    = P("\t")
parsers.newline                = P("\n")
parsers.tightblocksep          = P("\001")

parsers.digit                  = R("09")
parsers.hexdigit               = R("09","af","AF")
parsers.letter                 = R("AZ","az")
parsers.alphanumeric           = R("AZ","az","09")
parsers.keyword                = parsers.letter
                               * parsers.alphanumeric^0
parsers.citation_chars         = parsers.alphanumeric
                               + S("#$%&-+<>~/_")
parsers.internal_punctuation   = S(":;,.?")

parsers.doubleasterisks        = P("**")
parsers.doubleunderscores      = P("__")
parsers.fourspaces             = P("    ")

parsers.any                    = P(1)
parsers.fail                   = parsers.any - 1

parsers.escapable              = S("\\`*_{}[]()+_.!<>#-~:^@;")
parsers.anyescaped             = P("\\") / "" * parsers.escapable
                               + parsers.any

parsers.spacechar              = S("\t ")
parsers.spacing                = S(" \n\r\t")
parsers.nonspacechar           = parsers.any - parsers.spacing
parsers.optionalspace          = parsers.spacechar^0

parsers.specialchar            = S("*_`&[]<!\\.@-^")

parsers.normalchar             = parsers.any - (parsers.specialchar
                                                + parsers.spacing
                                                + parsers.tightblocksep)
parsers.eof                    = -parsers.any
parsers.nonindentspace         = parsers.space^-3 * - parsers.spacechar
parsers.indent                 = parsers.space^-3 * parsers.tab
                               + parsers.fourspaces / ""
parsers.linechar               = P(1 - parsers.newline)

parsers.blankline              = parsers.optionalspace
                               * parsers.newline / "\n"
parsers.blanklines             = parsers.blankline^0
parsers.skipblanklines         = (parsers.optionalspace * parsers.newline)^0
parsers.indentedline           = parsers.indent    /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.optionallyindentedline = parsers.indent^-1 /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.sp                     = parsers.spacing^0
parsers.spnl                   = parsers.optionalspace
                               * (parsers.newline * parsers.optionalspace)^-1
parsers.line                   = parsers.linechar^0 * parsers.newline
parsers.nonemptyline           = parsers.line - parsers.blankline

parsers.chunk                  = parsers.line * (parsers.optionallyindentedline
                                                - parsers.blankline)^0

parsers.css_identifier_char    = R("AZ", "az", "09") + S("-_")
parsers.css_identifier         = (parsers.hash + parsers.period)
                               * (((parsers.css_identifier_char
                                   - parsers.dash - parsers.digit)
                                  * parsers.css_identifier_char^1)
                                 + (parsers.dash
                                   * (parsers.css_identifier_char
                                     - parsers.digit)
                                   * parsers.css_identifier_char^0))
parsers.attribute_name_char    = parsers.any - parsers.space
                               - parsers.squote - parsers.dquote
                               - parsers.more - parsers.slash
                               - parsers.equal
parsers.attribute_value_char   = parsers.any - parsers.dquote
                               - parsers.more

-- block followed by 0 or more optionally
-- indented blocks with first line indented.
parsers.indented_blocks = function(bl)
  return Cs( bl
         * (parsers.blankline^1 * parsers.indent * -parsers.blankline * bl)^0
         * (parsers.blankline^1 + parsers.eof) )
end
parsers.bulletchar = C(parsers.plus + parsers.asterisk + parsers.dash)

parsers.bullet = ( parsers.bulletchar * #parsers.spacing
                                      * (parsers.tab + parsers.space^-3)
                 + parsers.space * parsers.bulletchar * #parsers.spacing
                                 * (parsers.tab + parsers.space^-2)
                 + parsers.space * parsers.space * parsers.bulletchar
                                 * #parsers.spacing
                                 * (parsers.tab + parsers.space^-1)
                 + parsers.space * parsers.space * parsers.space
                                 * parsers.bulletchar * #parsers.spacing
                 )
parsers.openticks   = Cg(parsers.backtick^1, "ticks")

local function captures_equal_length(s,i,a,b)
  return #a == #b and i
end

parsers.closeticks  = parsers.space^-1
                    * Cmt(C(parsers.backtick^1)
                         * Cb("ticks"), captures_equal_length)

parsers.intickschar = (parsers.any - S(" \n\r`"))
                    + (parsers.newline * -parsers.blankline)
                    + (parsers.space - parsers.closeticks)
                    + (parsers.backtick^1 - parsers.closeticks)

parsers.inticks     = parsers.openticks * parsers.space^-1
                    * C(parsers.intickschar^0) * parsers.closeticks
local function captures_geq_length(s,i,a,b)
  return #a >= #b and i
end

parsers.infostring     = (parsers.linechar - (parsers.backtick
                       + parsers.space^1 * (parsers.newline + parsers.eof)))^0

local fenceindent
parsers.fencehead    = function(char)
  return               C(parsers.nonindentspace) / function(s) fenceindent = #s end
                     * Cg(char^3, "fencelength")
                     * parsers.optionalspace * C(parsers.infostring)
                     * parsers.optionalspace * (parsers.newline + parsers.eof)
end

parsers.fencetail    = function(char)
  return               parsers.nonindentspace
                     * Cmt(C(char^3) * Cb("fencelength"), captures_geq_length)
                     * parsers.optionalspace * (parsers.newline + parsers.eof)
                     + parsers.eof
end

parsers.fencedline   = function(char)
  return               C(parsers.line - parsers.fencetail(char))
                     / function(s)
                         i = 1
                         remaining = fenceindent
                         while true do
                           c = s:sub(i, i)
                           if c == " " and remaining > 0 then
                             remaining = remaining - 1
                             i = i + 1
                           elseif c == "\t" and remaining > 3 then
                             remaining = remaining - 4
                             i = i + 1
                           else
                             break
                           end
                         end
                         return s:sub(i)
                       end
end
parsers.leader      = parsers.space^-3

-- content in balanced brackets, parentheses, or quotes:
parsers.bracketed   = P{ parsers.lbracket
                       * ((parsers.anyescaped - (parsers.lbracket
                                                + parsers.rbracket
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rbracket }

parsers.inparens    = P{ parsers.lparent
                       * ((parsers.anyescaped - (parsers.lparent
                                                + parsers.rparent
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rparent }

parsers.squoted     = P{ parsers.squote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.squote
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.squote }

parsers.dquoted     = P{ parsers.dquote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.dquote
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.dquote }

-- bracketed tag for markdown links, allowing nested brackets:
parsers.tag         = parsers.lbracket
                    * Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.blankline^2)))^0)
                    * parsers.rbracket

-- url for markdown links, allowing nested brackets:
parsers.url         = parsers.less * Cs((parsers.anyescaped
                                        - parsers.more)^0)
                                   * parsers.more
                    + Cs((parsers.inparens + (parsers.anyescaped
                                             - parsers.spacing
                                             - parsers.rparent))^1)

-- quoted text, possibly with nested quotes:
parsers.title_s     = parsers.squote * Cs(((parsers.anyescaped-parsers.squote)
                                           + parsers.squoted)^0)
                                     * parsers.squote

parsers.title_d     = parsers.dquote * Cs(((parsers.anyescaped-parsers.dquote)
                                           + parsers.dquoted)^0)
                                     * parsers.dquote

parsers.title_p     = parsers.lparent
                    * Cs((parsers.inparens + (parsers.anyescaped-parsers.rparent))^0)
                    * parsers.rparent

parsers.title       = parsers.title_d + parsers.title_s + parsers.title_p

parsers.optionaltitle
                    = parsers.spnl * parsers.title * parsers.spacechar^0
                    + Cc("")
parsers.contentblock_tail
                    = parsers.optionaltitle
                    * (parsers.newline + parsers.eof)

-- case insensitive online image suffix:
parsers.onlineimagesuffix
                    = (function(...)
                        local parser = nil
                        for _,suffix in ipairs({...}) do
                          local pattern=nil
                          for i=1,#suffix do
                            local char=suffix:sub(i,i)
                            char = S(char:lower()..char:upper())
                            if pattern == nil then
                              pattern = char
                            else
                              pattern = pattern * char
                            end
                          end
                          if parser == nil then
                            parser = pattern
                          else
                            parser = parser + pattern
                          end
                        end
                        return parser
                      end)("png", "jpg", "jpeg", "gif", "tif", "tiff")

-- online image url for iA Writer content blocks with mandatory suffix,
-- allowing nested brackets:
parsers.onlineimageurl
                    = (parsers.less
                      * Cs((parsers.anyescaped
                           - parsers.more
                           - #(parsers.period
                              * parsers.onlineimagesuffix
                              * parsers.more
                              * parsers.contentblock_tail))^0)
                      * parsers.period
                      * Cs(parsers.onlineimagesuffix)
                      * parsers.more
                      + (Cs((parsers.inparens
                            + (parsers.anyescaped
                              - parsers.spacing
                              - parsers.rparent
                              - #(parsers.period
                                 * parsers.onlineimagesuffix
                                 * parsers.contentblock_tail)))^0)
                        * parsers.period
                        * Cs(parsers.onlineimagesuffix))
                      ) * Cc("onlineimage")

-- filename for iA Writer content blocks with mandatory suffix:
parsers.localfilepath
                    = parsers.slash
                    * Cs((parsers.anyescaped
                         - parsers.tab
                         - parsers.newline
                         - #(parsers.period
                            * parsers.alphanumeric^1
                            * parsers.contentblock_tail))^1)
                    * parsers.period
                    * Cs(parsers.alphanumeric^1)
                    * Cc("localfile")
parsers.citation_name = Cs(parsers.dash^-1) * parsers.at
                      * Cs(parsers.citation_chars
                          * (((parsers.citation_chars + parsers.internal_punctuation
                              - parsers.comma - parsers.semicolon)
                             * -#((parsers.internal_punctuation - parsers.comma
                                  - parsers.semicolon)^0
                                 * -(parsers.citation_chars + parsers.internal_punctuation
                                    - parsers.comma - parsers.semicolon)))^0
                            * parsers.citation_chars)^-1)

parsers.citation_body_prenote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.blankline^2))
                         - (parsers.spnl * parsers.dash^-1 * parsers.at))^0)

parsers.citation_body_postnote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.semicolon
                             + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)

parsers.citation_body_chunk
                    = parsers.citation_body_prenote
                    * parsers.spnl * parsers.citation_name
                    * (parsers.internal_punctuation - parsers.semicolon)^-1
                    * parsers.spnl * parsers.citation_body_postnote

parsers.citation_body
                    = parsers.citation_body_chunk
                    * (parsers.semicolon * parsers.spnl
                      * parsers.citation_body_chunk)^0

parsers.citation_headless_body_postnote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.at
                             + parsers.semicolon + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)

parsers.citation_headless_body
                    = parsers.citation_headless_body_postnote
                    * (parsers.sp * parsers.semicolon * parsers.spnl
                      * parsers.citation_body_chunk)^0
local function strip_first_char(s)
  return s:sub(2)
end

parsers.RawNoteRef = #(parsers.lbracket * parsers.circumflex)
                   * parsers.tag / strip_first_char
local function make_pipe_table_rectangular(rows)
  local num_columns = #rows[2]
  local rectangular_rows = {}
  for i = 1, #rows do
    local row = rows[i]
    local rectangular_row = {}
    for j = 1, num_columns do
      rectangular_row[j] = row[j] or ""
    end
    table.insert(rectangular_rows, rectangular_row)
  end
  return rectangular_rows
end

local function pipe_table_row(allow_empty_first_column
                             , nonempty_column
                             , column_separator
                             , column)
  local row_beginning
  if allow_empty_first_column then
    row_beginning = -- empty first column
                    #(parsers.spacechar^4
                     * column_separator)
                  * parsers.optionalspace
                  * column
                  * parsers.optionalspace
                  -- non-empty first column
                  + parsers.nonindentspace
                  * nonempty_column^-1
                  * parsers.optionalspace
  else
    row_beginning = parsers.nonindentspace
                  * nonempty_column^-1
                  * parsers.optionalspace
  end

  return Ct(row_beginning
           * (-- single column with no leading pipes
              #(column_separator
               * parsers.optionalspace
               * parsers.newline)
             * column_separator
             * parsers.optionalspace
             -- single column with leading pipes or
             -- more than a single column
             + (column_separator
               * parsers.optionalspace
               * column
               * parsers.optionalspace)^1
             * (column_separator
               * parsers.optionalspace)^-1))
end

parsers.table_hline_separator = parsers.pipe + parsers.plus
parsers.table_hline_column = (parsers.dash
                             - #(parsers.dash
                                * (parsers.spacechar
                                  + parsers.table_hline_separator
                                  + parsers.newline)))^1
                           * (parsers.colon * Cc("r")
                             + parsers.dash * Cc("d"))
                           + parsers.colon
                           * (parsers.dash
                             - #(parsers.dash
                                * (parsers.spacechar
                                  + parsers.table_hline_separator
                                  + parsers.newline)))^1
                           * (parsers.colon * Cc("c")
                             + parsers.dash * Cc("l"))
parsers.table_hline = pipe_table_row(false
                                    , parsers.table_hline_column
                                    , parsers.table_hline_separator
                                    , parsers.table_hline_column)
parsers.table_caption_beginning = parsers.skipblanklines
                                * parsers.nonindentspace
                                * (P("Table")^-1 * parsers.colon)
                                * parsers.optionalspace
-- case-insensitive match (we assume s is lowercase). must be single byte encoding
parsers.keyword_exact = function(s)
  local parser = P(0)
  for i=1,#s do
    local c = s:sub(i,i)
    local m = c .. upper(c)
    parser = parser * S(m)
  end
  return parser
end

parsers.block_keyword =
    parsers.keyword_exact("address") + parsers.keyword_exact("blockquote") +
    parsers.keyword_exact("center") + parsers.keyword_exact("del") +
    parsers.keyword_exact("dir") + parsers.keyword_exact("div") +
    parsers.keyword_exact("p") + parsers.keyword_exact("pre") +
    parsers.keyword_exact("li") + parsers.keyword_exact("ol") +
    parsers.keyword_exact("ul") + parsers.keyword_exact("dl") +
    parsers.keyword_exact("dd") + parsers.keyword_exact("form") +
    parsers.keyword_exact("fieldset") + parsers.keyword_exact("isindex") +
    parsers.keyword_exact("ins") + parsers.keyword_exact("menu") +
    parsers.keyword_exact("noframes") + parsers.keyword_exact("frameset") +
    parsers.keyword_exact("h1") + parsers.keyword_exact("h2") +
    parsers.keyword_exact("h3") + parsers.keyword_exact("h4") +
    parsers.keyword_exact("h5") + parsers.keyword_exact("h6") +
    parsers.keyword_exact("hr") + parsers.keyword_exact("script") +
    parsers.keyword_exact("noscript") + parsers.keyword_exact("table") +
    parsers.keyword_exact("tbody") + parsers.keyword_exact("tfoot") +
    parsers.keyword_exact("thead") + parsers.keyword_exact("th") +
    parsers.keyword_exact("td") + parsers.keyword_exact("tr")

-- There is no reason to support bad html, so we expect quoted attributes
parsers.htmlattributevalue
                          = parsers.squote * (parsers.any - (parsers.blankline
                                                            + parsers.squote))^0
                                           * parsers.squote
                          + parsers.dquote * (parsers.any - (parsers.blankline
                                                            + parsers.dquote))^0
                                           * parsers.dquote

parsers.htmlattribute     = parsers.spacing^1
                          * (parsers.alphanumeric + S("_-"))^1
                          * parsers.sp * parsers.equal * parsers.sp
                          * parsers.htmlattributevalue

parsers.htmlcomment       = P("<!--") * (parsers.any - P("-->"))^0 * P("-->")

parsers.htmlinstruction   = P("<?")   * (parsers.any - P("?>" ))^0 * P("?>" )

parsers.openelt_any = parsers.less * parsers.keyword * parsers.htmlattribute^0
                    * parsers.sp * parsers.more

parsers.openelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.keyword_exact(s)
       * parsers.htmlattribute^0 * parsers.sp * parsers.more
end

parsers.openelt_block = parsers.sp * parsers.block_keyword
                      * parsers.htmlattribute^0 * parsers.sp * parsers.more

parsers.closeelt_any = parsers.less * parsers.sp * parsers.slash
                     * parsers.keyword * parsers.sp * parsers.more

parsers.closeelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.slash * parsers.keyword_exact(s)
       * parsers.sp * parsers.more
end

parsers.emptyelt_any = parsers.less * parsers.sp * parsers.keyword
                     * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                     * parsers.more

parsers.emptyelt_block = parsers.less * parsers.sp * parsers.block_keyword
                       * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                       * parsers.more

parsers.displaytext = (parsers.any - parsers.less)^1

-- return content between two matched HTML tags
parsers.in_matched = function(s)
  return { parsers.openelt_exact(s)
         * (V(1) + parsers.displaytext
           + (parsers.less - parsers.closeelt_exact(s)))^0
         * parsers.closeelt_exact(s) }
end

local function parse_matched_tags(s,pos)
  local t = string.lower(lpeg.match(C(parsers.keyword),s,pos))
  return lpeg.match(parsers.in_matched(t),s,pos-1)
end

parsers.in_matched_block_tags = parsers.less
                              * Cmt(#parsers.openelt_block, parse_matched_tags)

parsers.displayhtml = parsers.htmlcomment
                    + parsers.emptyelt_block
                    + parsers.openelt_exact("hr")
                    + parsers.in_matched_block_tags
                    + parsers.htmlinstruction

parsers.inlinehtml  = parsers.emptyelt_any
                    + parsers.htmlcomment
                    + parsers.htmlinstruction
                    + parsers.openelt_any
                    + parsers.closeelt_any
parsers.hexentity = parsers.ampersand * parsers.hash * S("Xx")
                  * C(parsers.hexdigit^1) * parsers.semicolon
parsers.decentity = parsers.ampersand * parsers.hash
                  * C(parsers.digit^1) * parsers.semicolon
parsers.tagentity = parsers.ampersand * C(parsers.alphanumeric^1)
                  * parsers.semicolon
-- parse a reference definition:  [foo]: /bar "title"
parsers.define_reference_parser = parsers.leader * parsers.tag * parsers.colon
                                * parsers.spacechar^0 * parsers.url
                                * parsers.optionaltitle * parsers.blankline^1
parsers.Inline         = V("Inline")
parsers.IndentedInline = V("IndentedInline")

-- parse many p between starter and ender
parsers.between = function(p, starter, ender)
  local ender2 = B(parsers.nonspacechar) * ender
  return (starter * #parsers.nonspacechar * Ct(p * (p - ender2)^0) * ender2)
end

parsers.urlchar      = parsers.anyescaped - parsers.newline - parsers.more
parsers.Block        = V("Block")

parsers.OnlineImageURL
                     = parsers.leader
                     * parsers.onlineimageurl
                     * parsers.optionaltitle

parsers.LocalFilePath
                     = parsers.leader
                     * parsers.localfilepath
                     * parsers.optionaltitle

parsers.TildeFencedCode
                     = parsers.fencehead(parsers.tilde)
                     * Cs(parsers.fencedline(parsers.tilde)^0)
                     * parsers.fencetail(parsers.tilde)

parsers.BacktickFencedCode
                     = parsers.fencehead(parsers.backtick)
                     * Cs(parsers.fencedline(parsers.backtick)^0)
                     * parsers.fencetail(parsers.backtick)

parsers.lineof = function(c)
    return (parsers.leader * (P(c) * parsers.optionalspace)^3
           * (parsers.newline * parsers.blankline^1
             + parsers.newline^-1 * parsers.eof))
end
parsers.defstartchar = S("~:")
parsers.defstart     = ( parsers.defstartchar * #parsers.spacing
                                              * (parsers.tab + parsers.space^-3)
                     + parsers.space * parsers.defstartchar * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * parsers.space * parsers.defstartchar
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * parsers.space
                                     * parsers.defstartchar * #parsers.spacing
                     )

parsers.dlchunk = Cs(parsers.line * (parsers.indentedline - parsers.blankline)^0)
parsers.heading_attribute = C(parsers.css_identifier)
                          + C((parsers.attribute_name_char
                             - parsers.rbrace)^1
                             * parsers.equal
                             * (parsers.attribute_value_char
                               - parsers.rbrace)^1)
parsers.HeadingAttributes = parsers.lbrace
                          * parsers.heading_attribute
                          * (parsers.spacechar^1
                            * parsers.heading_attribute)^0
                          * parsers.rbrace

-- parse Atx heading start and return level
parsers.HeadingStart = #parsers.hash * C(parsers.hash^-6)
                     * -parsers.hash / length

-- parse setext header ending and return level
parsers.HeadingLevel = parsers.equal^1 * Cc(1) + parsers.dash^1 * Cc(2)

local function strip_atx_end(s)
  return s:gsub("[#%s]*\n$","")
end
M.reader = {}
function M.reader.new(writer, options)
  local self = {}
  options = options or {}
  setmetatable(options, { __index = function (_, key)
    return defaultOptions[key] end })
  local function normalize_tag(tag)
    return unicode.utf8.lower(
      gsub(util.rope_to_string(tag), "[ \n\r\t]+", " "))
  end
  local expandtabs
  if options.preserveTabs then
    expandtabs = function(s) return s end
  else
    expandtabs = function(s)
                   if s:find("\t") then
                     return s:gsub("[^\n]*", util.expand_tabs_in_line)
                   else
                     return s
                   end
                 end
  end
  local larsers    = {}
  local function create_parser(name, grammar)
    return function(str)
      local res = lpeg.match(grammar(), str)
      if res == nil then
        error(format("%s failed on:\n%s", name, str:sub(1,20)))
      else
        return res
      end
    end
  end

  local parse_blocks
    = create_parser("parse_blocks",
                    function()
                      return larsers.blocks
                    end)

  local parse_blocks_toplevel
    = create_parser("parse_blocks_toplevel",
                    function()
                      return larsers.blocks_toplevel
                    end)

  local parse_inlines
    = create_parser("parse_inlines",
                    function()
                      return larsers.inlines
                    end)

  local parse_inlines_no_link
    = create_parser("parse_inlines_no_link",
                    function()
                      return larsers.inlines_no_link
                    end)

  local parse_inlines_no_inline_note
    = create_parser("parse_inlines_no_inline_note",
                    function()
                      return larsers.inlines_no_inline_note
                    end)

  local parse_inlines_nbsp
    = create_parser("parse_inlines_nbsp",
                    function()
                      return larsers.inlines_nbsp
                    end)
  if options.hashEnumerators then
    larsers.dig = parsers.digit + parsers.hash
  else
    larsers.dig = parsers.digit
  end

  larsers.enumerator = C(larsers.dig^3 * parsers.period) * #parsers.spacing
                     + C(larsers.dig^2 * parsers.period) * #parsers.spacing
                                       * (parsers.tab + parsers.space^1)
                     + C(larsers.dig * parsers.period) * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * C(larsers.dig^2 * parsers.period)
                                     * #parsers.spacing
                     + parsers.space * C(larsers.dig * parsers.period)
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * C(larsers.dig^1
                                     * parsers.period) * #parsers.spacing
  -- strip off leading > and indents, and run through blocks
  larsers.blockquote_body = ((parsers.leader * parsers.more * parsers.space^-1)/""
                             * parsers.linechar^0 * parsers.newline)^1
                            * (-(parsers.leader * parsers.more
                                + parsers.blankline) * parsers.linechar^1
                              * parsers.newline)^0

  if not options.breakableBlockquotes then
    larsers.blockquote_body = larsers.blockquote_body
                            * (parsers.blankline^0 / "")
  end
  larsers.citations = function(text_cites, raw_cites)
      local function normalize(str)
          if str == "" then
              str = nil
          else
              str = (options.citationNbsps and parse_inlines_nbsp or
                parse_inlines)(str)
          end
          return str
      end

      local cites = {}
      for i = 1,#raw_cites,4 do
          cites[#cites+1] = {
              prenote = normalize(raw_cites[i]),
              suppress_author = raw_cites[i+1] == "-",
              name = writer.citation(raw_cites[i+2]),
              postnote = normalize(raw_cites[i+3]),
          }
      end
      return writer.citations(text_cites, cites)
  end
  local rawnotes = {}

  -- like indirect_link
  local function lookup_note(ref)
    return function()
      local found = rawnotes[normalize_tag(ref)]
      if found then
        return writer.note(parse_blocks_toplevel(found))
      else
        return {"[", parse_inlines("^" .. ref), "]"}
      end
    end
  end

  local function register_note(ref,rawnote)
    rawnotes[normalize_tag(ref)] = rawnote
    return ""
  end

  larsers.NoteRef    = parsers.RawNoteRef / lookup_note

  larsers.NoteBlock  = parsers.leader * parsers.RawNoteRef * parsers.colon
                     * parsers.spnl * parsers.indented_blocks(parsers.chunk)
                     / register_note

  larsers.InlineNote = parsers.circumflex
                     * (parsers.tag / parse_inlines_no_inline_note) -- no notes inside notes
                     / writer.note
larsers.table_row = pipe_table_row(true
                                  , (C((parsers.linechar - parsers.pipe)^1)
                                    / parse_inlines)
                                  , parsers.pipe
                                  , (C((parsers.linechar - parsers.pipe)^0)
                                    / parse_inlines))

if options.tableCaptions then
  larsers.table_caption = #parsers.table_caption_beginning
                        * parsers.table_caption_beginning
                        * Ct(parsers.IndentedInline^1)
                        * parsers.newline
else
  larsers.table_caption = parsers.fail
end

larsers.PipeTable = Ct(larsers.table_row * parsers.newline
                    * parsers.table_hline
                    * (parsers.newline * larsers.table_row)^0)
                  / make_pipe_table_rectangular
                  * larsers.table_caption^-1
                  / writer.table
  -- List of references defined in the document
  local references

  -- add a reference to the list
  local function register_link(tag,url,title)
      references[normalize_tag(tag)] = { url = url, title = title }
      return ""
  end

  -- lookup link reference and return either
  -- the link or nil and fallback text.
  local function lookup_reference(label,sps,tag)
      local tagpart
      if not tag then
          tag = label
          tagpart = ""
      elseif tag == "" then
          tag = label
          tagpart = "[]"
      else
          tagpart = {"[", parse_inlines(tag), "]"}
      end
      if sps then
        tagpart = {sps, tagpart}
      end
      local r = references[normalize_tag(tag)]
      if r then
        return r
      else
        return nil, {"[", parse_inlines(label), "]", tagpart}
      end
  end

  -- lookup link reference and return a link, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_link(label,sps,tag)
    return function()
      local r,fallback = lookup_reference(label,sps,tag)
      if r then
        return writer.link(parse_inlines_no_link(label), r.url, r.title)
      else
        return fallback
      end
    end
  end

  -- lookup image reference and return an image, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_image(label,sps,tag)
    return function()
      local r,fallback = lookup_reference(label,sps,tag)
      if r then
        return writer.image(writer.string(label), r.url, r.title)
      else
        return {"!", fallback}
      end
    end
  end
  larsers.Str      = parsers.normalchar^1 / writer.string

  larsers.Symbol   = (parsers.specialchar - parsers.tightblocksep)
                   / writer.string

  larsers.Ellipsis = P("...") / writer.ellipsis

  larsers.Smart    = larsers.Ellipsis

  larsers.Code     = parsers.inticks / writer.code

  if options.blankBeforeBlockquote then
    larsers.bqstart = parsers.fail
  else
    larsers.bqstart = parsers.more
  end

  if options.blankBeforeHeading then
    larsers.headerstart = parsers.fail
  else
    larsers.headerstart = parsers.hash
                        + (parsers.line * (parsers.equal^1 + parsers.dash^1)
                        * parsers.optionalspace * parsers.newline)
  end

  if not options.fencedCode or options.blankBeforeCodeFence then
    larsers.fencestart = parsers.fail
  else
    larsers.fencestart = parsers.fencehead(parsers.backtick)
                       + parsers.fencehead(parsers.tilde)
  end

  larsers.Endline   = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + larsers.bqstart
                      + larsers.headerstart
                      + larsers.fencestart
                    ) * parsers.spacechar^0 / writer.space

  larsers.OptionalIndent
                     = parsers.spacechar^1 / writer.space

  larsers.Space      = parsers.spacechar^2 * larsers.Endline / writer.linebreak
                     + parsers.spacechar^1 * larsers.Endline^-1 * parsers.eof / ""
                     + parsers.spacechar^1 * larsers.Endline^-1
                                           * parsers.optionalspace / writer.space

  larsers.NonbreakingEndline
                    = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + larsers.bqstart
                      + larsers.headerstart
                      + larsers.fencestart
                    ) * parsers.spacechar^0 / writer.nbsp

  larsers.NonbreakingSpace
                  = parsers.spacechar^2 * larsers.Endline / writer.linebreak
                  + parsers.spacechar^1 * larsers.Endline^-1 * parsers.eof / ""
                  + parsers.spacechar^1 * larsers.Endline^-1
                                        * parsers.optionalspace / writer.nbsp

  if options.underscores then
    larsers.Strong = ( parsers.between(parsers.Inline, parsers.doubleasterisks,
                                       parsers.doubleasterisks)
                     + parsers.between(parsers.Inline, parsers.doubleunderscores,
                                       parsers.doubleunderscores)
                     ) / writer.strong

    larsers.Emph   = ( parsers.between(parsers.Inline, parsers.asterisk,
                                       parsers.asterisk)
                     + parsers.between(parsers.Inline, parsers.underscore,
                                       parsers.underscore)
                     ) / writer.emphasis
  else
    larsers.Strong = ( parsers.between(parsers.Inline, parsers.doubleasterisks,
                                       parsers.doubleasterisks)
                     ) / writer.strong

    larsers.Emph   = ( parsers.between(parsers.Inline, parsers.asterisk,
                                       parsers.asterisk)
                     ) / writer.emphasis
  end

  larsers.AutoLinkUrl    = parsers.less
                         * C(parsers.alphanumeric^1 * P("://") * parsers.urlchar^1)
                         * parsers.more
                         / function(url)
                             return writer.link(writer.string(url), url)
                           end

  larsers.AutoLinkEmail = parsers.less
                        * C((parsers.alphanumeric + S("-._+"))^1
                        * P("@") * parsers.urlchar^1)
                        * parsers.more
                        / function(email)
                            return writer.link(writer.string(email),
                                               "mailto:"..email)
                          end

  larsers.DirectLink    = (parsers.tag / parse_inlines_no_link)  -- no links inside links
                        * parsers.spnl
                        * parsers.lparent
                        * (parsers.url + Cc(""))  -- link can be empty [foo]()
                        * parsers.optionaltitle
                        * parsers.rparent
                        / writer.link

  larsers.IndirectLink  = parsers.tag * (C(parsers.spnl) * parsers.tag)^-1
                        / indirect_link

  -- parse a link or image (direct or indirect)
  larsers.Link          = larsers.DirectLink + larsers.IndirectLink

  larsers.DirectImage   = parsers.exclamation
                        * (parsers.tag / parse_inlines)
                        * parsers.spnl
                        * parsers.lparent
                        * (parsers.url + Cc(""))  -- link can be empty [foo]()
                        * parsers.optionaltitle
                        * parsers.rparent
                        / writer.image

  larsers.IndirectImage = parsers.exclamation * parsers.tag
                        * (C(parsers.spnl) * parsers.tag)^-1 / indirect_image

  larsers.Image         = larsers.DirectImage + larsers.IndirectImage

  larsers.TextCitations = Ct(Cc("")
                        * parsers.citation_name
                        * ((parsers.spnl
                            * parsers.lbracket
                            * parsers.citation_headless_body
                            * parsers.rbracket) + Cc("")))
                        / function(raw_cites)
                            return larsers.citations(true, raw_cites)
                          end

  larsers.ParenthesizedCitations
                        = Ct(parsers.lbracket
                        * parsers.citation_body
                        * parsers.rbracket)
                        / function(raw_cites)
                            return larsers.citations(false, raw_cites)
                          end

  larsers.Citations     = larsers.TextCitations + larsers.ParenthesizedCitations

  -- avoid parsing long strings of * or _ as emph/strong
  larsers.UlOrStarLine  = parsers.asterisk^4 + parsers.underscore^4
                        / writer.string

  larsers.EscapedChar   = S("\\") * C(parsers.escapable) / writer.string

  larsers.InlineHtml    = C(parsers.inlinehtml) / writer.inline_html

  larsers.HtmlEntity    = parsers.hexentity / entities.hex_entity  / writer.string
                        + parsers.decentity / entities.dec_entity  / writer.string
                        + parsers.tagentity / entities.char_entity / writer.string
  larsers.ContentBlock = parsers.leader
                       * (parsers.localfilepath + parsers.onlineimageurl)
                       * parsers.contentblock_tail
                       / writer.contentblock

  larsers.DisplayHtml  = C(parsers.displayhtml)
                       / expandtabs / writer.display_html

  larsers.Verbatim     = Cs( (parsers.blanklines
                           * ((parsers.indentedline - parsers.blankline))^1)^1
                           ) / expandtabs / writer.verbatim

  larsers.FencedCode   = (parsers.TildeFencedCode
                         + parsers.BacktickFencedCode)
                       / function(infostring, code)
                           return writer.fencedCode(writer.string(infostring),
                                                    expandtabs(code))
                         end

  larsers.Blockquote   = Cs(larsers.blockquote_body^1)
                       / parse_blocks_toplevel / writer.blockquote

  larsers.HorizontalRule = ( parsers.lineof(parsers.asterisk)
                           + parsers.lineof(parsers.dash)
                           + parsers.lineof(parsers.underscore)
                           ) / writer.hrule

  larsers.Reference    = parsers.define_reference_parser / register_link

  larsers.Paragraph    = parsers.nonindentspace * Ct(parsers.Inline^1)
                       * parsers.newline
                       * ( parsers.blankline^1
                         + #parsers.hash
                         + #(parsers.leader * parsers.more * parsers.space^-1)
                         )
                       / writer.paragraph

  larsers.ToplevelParagraph
                       = parsers.nonindentspace * Ct(parsers.Inline^1)
                       * ( parsers.newline
                       * ( parsers.blankline^1
                         + #parsers.hash
                         + #(parsers.leader * parsers.more * parsers.space^-1)
                         + parsers.eof
                         )
                       + parsers.eof )
                       / writer.paragraph

  larsers.Plain        = parsers.nonindentspace * Ct(parsers.Inline^1)
                       / writer.plain
  larsers.starter = parsers.bullet + larsers.enumerator

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  larsers.NestedList            = Cs((parsers.optionallyindentedline
                                     - larsers.starter)^1)
                                / function(a) return "\001"..a end

  larsers.ListBlockLine         = parsers.optionallyindentedline
                                - parsers.blankline - (parsers.indent^-1
                                                      * larsers.starter)

  larsers.ListBlock             = parsers.line * larsers.ListBlockLine^0

  larsers.ListContinuationBlock = parsers.blanklines * (parsers.indent / "")
                                * larsers.ListBlock

  larsers.TightListItem = function(starter)
      return -larsers.HorizontalRule
             * (Cs(starter / "" * larsers.ListBlock * larsers.NestedList^-1)
               / parse_blocks)
             * -(parsers.blanklines * parsers.indent)
  end

  larsers.LooseListItem = function(starter)
      return -larsers.HorizontalRule
             * Cs( starter / "" * larsers.ListBlock * Cc("\n")
               * (larsers.NestedList + larsers.ListContinuationBlock^0)
               * (parsers.blanklines / "\n\n")
               ) / parse_blocks
  end

  larsers.BulletList = ( Ct(larsers.TightListItem(parsers.bullet)^1) * Cc(true)
                       * parsers.skipblanklines * -parsers.bullet
                       + Ct(larsers.LooseListItem(parsers.bullet)^1) * Cc(false)
                       * parsers.skipblanklines )
                     / writer.bulletlist

  local function ordered_list(items,tight,startNumber)
    if options.startNumber then
      startNumber = tonumber(startNumber) or 1  -- fallback for '#'
      if startNumber ~= nil then
        startNumber = math.floor(startNumber)
      end
    else
      startNumber = nil
    end
    return writer.orderedlist(items,tight,startNumber)
  end

  larsers.OrderedList = Cg(larsers.enumerator, "listtype") *
                      ( Ct(larsers.TightListItem(Cb("listtype"))
                          * larsers.TightListItem(larsers.enumerator)^0)
                      * Cc(true) * parsers.skipblanklines * -larsers.enumerator
                      + Ct(larsers.LooseListItem(Cb("listtype"))
                          * larsers.LooseListItem(larsers.enumerator)^0)
                      * Cc(false) * parsers.skipblanklines
                      ) * Cb("listtype") / ordered_list

  local function definition_list_item(term, defs, tight)
    return { term = parse_inlines(term), definitions = defs }
  end

  larsers.DefinitionListItemLoose = C(parsers.line) * parsers.skipblanklines
                                  * Ct((parsers.defstart
                                       * parsers.indented_blocks(parsers.dlchunk)
                                       / parse_blocks_toplevel)^1)
                                  * Cc(false) / definition_list_item

  larsers.DefinitionListItemTight = C(parsers.line)
                                  * Ct((parsers.defstart * parsers.dlchunk
                                       / parse_blocks)^1)
                                  * Cc(true) / definition_list_item

  larsers.DefinitionList = ( Ct(larsers.DefinitionListItemLoose^1) * Cc(false)
                           + Ct(larsers.DefinitionListItemTight^1)
                           * (parsers.skipblanklines
                             * -larsers.DefinitionListItemLoose * Cc(true))
                           ) / writer.definitionlist
  larsers.Blank        = parsers.blankline / ""
                       + larsers.NoteBlock
                       + larsers.Reference
                       + (parsers.tightblocksep / "\n")
  -- parse atx header
  if options.headerAttributes then
    larsers.AtxHeading = Cg(parsers.HeadingStart,"level")
                       * parsers.optionalspace
                       * (C(((parsers.linechar
                             - ((parsers.hash^1
                                * parsers.optionalspace
                                * parsers.HeadingAttributes^-1
                                + parsers.HeadingAttributes)
                               * parsers.optionalspace
                               * parsers.newline))
                            * (parsers.linechar
                              - parsers.hash
                              - parsers.lbrace)^0)^1)
                           / parse_inlines)
                       * Cg(Ct(parsers.newline
                              + (parsers.hash^1
                                * parsers.optionalspace
                                * parsers.HeadingAttributes^-1
                                + parsers.HeadingAttributes)
                              * parsers.optionalspace
                              * parsers.newline), "attributes")
                       * Cb("level")
                       * Cb("attributes")
                       / writer.heading

    larsers.SetextHeading = #(parsers.line * S("=-"))
                          * (C(((parsers.linechar
                                - (parsers.HeadingAttributes
                                  * parsers.optionalspace
                                  * parsers.newline))
                               * (parsers.linechar
                                 - parsers.lbrace)^0)^1)
                              / parse_inlines)
                          * Cg(Ct(parsers.newline
                                 + (parsers.HeadingAttributes
                                   * parsers.optionalspace
                                   * parsers.newline)), "attributes")
                          * parsers.HeadingLevel
                          * Cb("attributes")
                          * parsers.optionalspace
                          * parsers.newline
                          / writer.heading
  else
    larsers.AtxHeading = Cg(parsers.HeadingStart,"level")
                       * parsers.optionalspace
                       * (C(parsers.line) / strip_atx_end / parse_inlines)
                       * Cb("level")
                       / writer.heading

    larsers.SetextHeading = #(parsers.line * S("=-"))
                          * Ct(parsers.linechar^1 / parse_inlines)
                          * parsers.newline
                          * parsers.HeadingLevel
                          * parsers.optionalspace
                          * parsers.newline
                          / writer.heading
  end

  larsers.Heading = larsers.AtxHeading + larsers.SetextHeading
  local syntax =
    { "Blocks",

      Blocks                = larsers.Blank^0 * parsers.Block^-1
                            * (larsers.Blank^0 / writer.interblocksep
                              * parsers.Block)^0
                            * larsers.Blank^0 * parsers.eof,

      Blank                 = larsers.Blank,

      Block                 = V("ContentBlock")
                            + V("Blockquote")
                            + V("PipeTable")
                            + V("Verbatim")
                            + V("FencedCode")
                            + V("HorizontalRule")
                            + V("BulletList")
                            + V("OrderedList")
                            + V("Heading")
                            + V("DefinitionList")
                            + V("DisplayHtml")
                            + V("Paragraph")
                            + V("Plain"),

      ContentBlock          = larsers.ContentBlock,
      Blockquote            = larsers.Blockquote,
      Verbatim              = larsers.Verbatim,
      FencedCode            = larsers.FencedCode,
      HorizontalRule        = larsers.HorizontalRule,
      BulletList            = larsers.BulletList,
      OrderedList           = larsers.OrderedList,
      Heading               = larsers.Heading,
      DefinitionList        = larsers.DefinitionList,
      DisplayHtml           = larsers.DisplayHtml,
      Paragraph             = larsers.Paragraph,
      PipeTable             = larsers.PipeTable,
      Plain                 = larsers.Plain,

      Inline                = V("Str")
                            + V("Space")
                            + V("Endline")
                            + V("UlOrStarLine")
                            + V("Strong")
                            + V("Emph")
                            + V("InlineNote")
                            + V("NoteRef")
                            + V("Citations")
                            + V("Link")
                            + V("Image")
                            + V("Code")
                            + V("AutoLinkUrl")
                            + V("AutoLinkEmail")
                            + V("InlineHtml")
                            + V("HtmlEntity")
                            + V("EscapedChar")
                            + V("Smart")
                            + V("Symbol"),

      IndentedInline        = V("Str")
                            + V("OptionalIndent")
                            + V("Endline")
                            + V("UlOrStarLine")
                            + V("Strong")
                            + V("Emph")
                            + V("InlineNote")
                            + V("NoteRef")
                            + V("Citations")
                            + V("Link")
                            + V("Image")
                            + V("Code")
                            + V("AutoLinkUrl")
                            + V("AutoLinkEmail")
                            + V("InlineHtml")
                            + V("HtmlEntity")
                            + V("EscapedChar")
                            + V("Smart")
                            + V("Symbol"),

      Str                   = larsers.Str,
      Space                 = larsers.Space,
      OptionalIndent        = larsers.OptionalIndent,
      Endline               = larsers.Endline,
      UlOrStarLine          = larsers.UlOrStarLine,
      Strong                = larsers.Strong,
      Emph                  = larsers.Emph,
      InlineNote            = larsers.InlineNote,
      NoteRef               = larsers.NoteRef,
      Citations             = larsers.Citations,
      Link                  = larsers.Link,
      Image                 = larsers.Image,
      Code                  = larsers.Code,
      AutoLinkUrl           = larsers.AutoLinkUrl,
      AutoLinkEmail         = larsers.AutoLinkEmail,
      InlineHtml            = larsers.InlineHtml,
      HtmlEntity            = larsers.HtmlEntity,
      EscapedChar           = larsers.EscapedChar,
      Smart                 = larsers.Smart,
      Symbol                = larsers.Symbol,
    }

  if not options.citations then
    syntax.Citations = parsers.fail
  end

  if not options.contentBlocks then
    syntax.ContentBlock = parsers.fail
  end

  if not options.codeSpans then
    syntax.Code = parsers.fail
  end

  if not options.definitionLists then
    syntax.DefinitionList = parsers.fail
  end

  if not options.fencedCode then
    syntax.FencedCode = parsers.fail
  end

  if not options.footnotes then
    syntax.NoteRef = parsers.fail
  end

  if not options.html then
    syntax.DisplayHtml = parsers.fail
    syntax.InlineHtml = parsers.fail
    syntax.HtmlEntity  = parsers.fail
  end

  if not options.inlineFootnotes then
    syntax.InlineNote = parsers.fail
  end

  if not options.smartEllipses then
    syntax.Smart = parsers.fail
  end

  if not options.pipeTables then
    syntax.PipeTable = parsers.fail
  end

  local blocks_toplevel_t = util.table_copy(syntax)
  blocks_toplevel_t.Paragraph = larsers.ToplevelParagraph
  larsers.blocks_toplevel = Ct(blocks_toplevel_t)

  larsers.blocks = Ct(syntax)

  local inlines_t = util.table_copy(syntax)
  inlines_t[1] = "Inlines"
  inlines_t.Inlines = parsers.Inline^0 * (parsers.spacing^0 * parsers.eof / "")
  larsers.inlines = Ct(inlines_t)

  local inlines_no_link_t = util.table_copy(inlines_t)
  inlines_no_link_t.Link = parsers.fail
  larsers.inlines_no_link = Ct(inlines_no_link_t)

  local inlines_no_inline_note_t = util.table_copy(inlines_t)
  inlines_no_inline_note_t.InlineNote = parsers.fail
  larsers.inlines_no_inline_note = Ct(inlines_no_inline_note_t)

  local inlines_nbsp_t = util.table_copy(inlines_t)
  inlines_nbsp_t.Endline = larsers.NonbreakingEndline
  inlines_nbsp_t.Space = larsers.NonbreakingSpace
  larsers.inlines_nbsp = Ct(inlines_nbsp_t)
  function self.convert(input)
    references = {}
    local opt_string = {}
    for k,_ in pairs(defaultOptions) do
      local v = options[k]
      if k ~= "cacheDir" then
        opt_string[#opt_string+1] = k .. "=" .. tostring(v)
      end
    end
    table.sort(opt_string)
    local salt = table.concat(opt_string, ",") .. "," .. metadata.version
    local name = util.cache(options.cacheDir, input, salt, function(input)
        return util.rope_to_string(parse_blocks_toplevel(input)) .. writer.eof
      end, ".md" .. writer.suffix)
    return writer.pack(name)
  end
  return self
end
function M.new(options)
  local writer = M.writer.new(options)
  local reader = M.reader.new(writer, options)
  return reader.convert
end

return M
