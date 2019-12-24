/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

static std::string curr_string;
static int comment_stack = 0;
static int string_null = 0;

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
TRUE            t(?i:rue)
FALSE           f(?i:alse)
WHITESPACE      [ \t\f\v\r]+
INTEGER         [0-9]+
IDCHAR          [a-zA-Z0-9_]
OBJECTID        [a-z]{IDCHAR}*
TYPEID          [A-Z]{IDCHAR}*
PRECEDENCE      [\,\.\@\~\*\/\+\-\<\=\(\)\{\}\:\;]

%x COMMENT INLINE_COMMENT STRING

%%

 /*
  *  Nested comments
  */
\(\*          { BEGIN COMMENT; comment_stack++; }

<COMMENT>\(\* {
  comment_stack++;
}

<COMMENT>\*\) { 
  comment_stack--; 
  if (comment_stack == 0) {
    BEGIN INITIAL;
  }
}

\*\) { 
  BEGIN INITIAL;
  yylval.error_msg = "Unmatched *)";
  return ERROR;
}

<COMMENT>\n   { curr_lineno++; }

<COMMENT><<EOF>> {
  BEGIN INITIAL;
  yylval.error_msg = "EOF in comment";
  return ERROR;
}

<COMMENT>.    { }

<INITIAL>--             { BEGIN INLINE_COMMENT; }
<INLINE_COMMENT>\n      { curr_lineno++; BEGIN INITIAL; }
<INLINE_COMMENT><<EOF>> { BEGIN INITIAL; }
<INLINE_COMMENT>.       { }


 /*
  *  The multiple-character operators.
  */
{DARROW}		  { return (DARROW); }
"<="          { return LE; }
"<-"          { return ASSIGN; }
{PRECEDENCE}  { return int(yytext[0]); }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

(?i:class)    { return CLASS; }
(?i:else)     { return ELSE; }
(?i:fi)       { return FI; }
(?i:if)       { return IF; }
(?i:in)       { return IN; }
(?i:inherits) { return INHERITS; }
(?i:isvoid)   { return ISVOID; }
(?i:let)      { return LET; }
(?i:loop)     { return LOOP; }
(?i:pool)     { return POOL; }
(?i:then)     { return THEN; }
(?i:while)    { return WHILE; }
(?i:case)     { return CASE; }
(?i:esac)     { return ESAC; }
(?i:new)      { return NEW; }
(?i:of)       { return OF; }
(?i:not)      { return NOT; }

{TRUE}        { yylval.boolean = 1; return BOOL_CONST; }
{FALSE}       { yylval.boolean = 0; return BOOL_CONST; }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
{INTEGER} {
  yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}

{TYPEID} {
  yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}

{OBJECTID} {
  yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}

\" {
  BEGIN STRING;
  curr_string = "";
  string_null = 0;
}

<STRING>\" {
  BEGIN INITIAL;
  if (curr_string.size() >= MAX_STR_CONST) {
    yylval.error_msg = "String constant too long";
    return ERROR;
  }
  if (string_null > 0) {
    yylval.error_msg = "String contains null character";
    return ERROR;
  } else {
    yylval.symbol = stringtable.add_string((char *) curr_string.c_str());
    return STR_CONST;
  }
}


<STRING>\\. {
  switch (yytext[1]) {
    case 'b':
      curr_string += '\b';
      break;
    case 't':
      curr_string += '\t';
      break;
    case 'n':
      curr_string += '\n';
      break;
    case 'f':
      curr_string += '\f';
      break;
    case '\0':
      string_null++;
      break;
    default:
      curr_string += yytext[1];
      break;
  }
}

<STRING>\\\n {
  curr_string += '\n';
  curr_lineno++;
}

<STRING>\n {
  BEGIN INITIAL;
  yylval.error_msg = "Unterminated string constant";
  return ERROR;
}

<STRING>\0 {
  string_null++;
}

<STRING><<EOF>> {
  BEGIN INITIAL;
  yylval.error_msg = "EOF in string constant";
  return ERROR;
}

<STRING>. {
  curr_string += yytext;
}

\'.\' {
  yylval.symbol = stringtable.add_string(&yytext[1]);
  return STR_CONST;
}

{WHITESPACE} { }

\n {
  curr_lineno++;
}

. {
  yylval.error_msg = yytext;
  return ERROR;
}



%%
