/**** files and options ****/
int  f_source;  /* source file */

/**** source program input  ****/

enum{ UNPACK=4 };
  /* WL assumes sizeof(int)=4;                            */
enum{ M_line=25, M_line_c=M_line*UNPACK };
int  line[M_line], line_c[M_line_c], lcp, lcm;
  /* a character string is packed into an int array with  */
  /* a terminator '\0'; it will be unpacked into another  */
  /* array one charater per element.                      */
  /* line holds the current line in packed form;          */
  /* line_c holds the current line in unpacked form,      */
  /* whereas lcm shows the number of characters in it,    */
  /* and lcp points to the next character position.       */
enum{ M_char=0x80 }; /* characters are in 7bit code       */
enum{ EOFC=0x04 };   /* EOF state is coded to this value. */
int  ch;       /* the next character available */
int  line_no;  /* current line number */

init_char(){
  f_source= stdin;  /* <== This line will be removed. */
  lcp= lcm= 0;  line_no= 0;
}
get_char(){
  if( lcp>=lcm ){
    if( fgets(line, M_line, f_source)==NULL ){
      line_c[0]= EOFC;  lcm= 1;
    }else{
      lcm= unpack(line, line_c);
    }
    lcp= 0;  line_no= line_no+1;
  }
  ch= line_c[lcp]%M_char;  /* filter to 7bits */
  if( ch!=EOFC )  lcp= lcp+1;
    /* not to try input again for an EOF'ed file */
}

/**** output ****/

/* number */

positive(int number, int file){
/* output a positive number to a file */

  if( number>=10 )  positive(number/10, file);
  fputc(number%10+'0', file);
}

decimal(int number, int file){
/* output a number in decimal onto a file */

  if( number<0 ){ 
    number= -number;  fputc('-', file);  
    if( number<0 ){ fputs("2147483648", file); return; }
  }
  positive(number, file);
}

/* error message output: to stderr */
system_error(int message[]){
/* output a message and aborts the compilation */

  decimal(line_no, stderr); fputs("::SYSTEM::", stderr);
  fputs(message, stderr); fputc('\0', stderr);
  exit(-1);
}

/**** token output ****/
enum{
  Else, Enum, If, Int, Return, While,
  Name, Const, Character, String,
  Plus, Minus, Not, Amper,
  Times, Divide, Remainder,
  Les, Leq, Grat, Geq,
  Equ, Neq,
  And, Or,
  Becomes,
  Comma, Semicolon, Lpar, Rpar, Lbracket, Rbracket, Lbrace, Rbrace,
  Nontoken, Endfile, Comment
};

int  token;  /* next token */
int  value;  /* integer value for token=Const,Character */
int  spell;  /* spelling for token=Name */
int  word[M_line];  /* contents for token=String, Comment */

/**** Name identity ****/
enum{ id_p, next_p, spell_p };  /* spell_table's components */

enum{ M_spell_table=2000 };                    /* size of spell_table */
int  spell_table[M_spell_table], spell_index;  /* for usual names */
  /* any name is identified with a positon p in this table;   */
  /*  spell_table[p+id_p]:    open for clients(defaults to 0) */
  /*  spell_table[p+next_p]:  link to similar spellings       */
  /*  spell_table[p+spell_p] and upward: packed spelling      */

/**** hashing ****/

/** Reserved Words  **/
enum{ M_reserved=6 };   /* number of reserved words */
enum{ M_spell_r=11  };  /* size of reserved word spelling */
enum{ P_r= 2, M_r= 7 }; /* hash function parameters */
enum{ NIL=-1 }; 

int token_r[M_r];            /* token for each reserved word */
int spell_r[M_spell_r], srp; /* spell table for reserved words */ 
int spell_rp[M_r];           /* pointer to their spelling */


int h(int spell_c[], int length, int P, int M){ int i, v;
/* computes a hash function value for an unpacked spell */
/* with parameters P and M.                             */

  v= 0; i= 0;
  while( i!=length ){
    v= (v*P + spell_c[i])%M;  i= i+1;
  }
  return v;
}

enter_reserved(int spell[], int token_value){
/* helper function: used by init_reserved */

  int spell_c[M_line_c], scm;  /* unpacked spell */
  int r;

  scm= unpack(spell, spell_c);
  r= h(spell_c, scm, P_r, M_r);
  spell_rp[r]= srp;  token_r[r]= token_value;
  srp= srp+pack(spell_c, scm, &spell_r[srp]);  
}

init_reserved(){ int i;
/* sets up tables related to the reserved words */

  i= 0; while( i!=M_r ){ token_r[i]= Name; spell_rp[i]= 0; i= i+1; }
  spell_r[0]= 0;  srp= 1;
  enter_reserved("else",  Else);
  enter_reserved("enum",  Enum);
  enter_reserved("if",    If);
  enter_reserved("int",   Int);
  enter_reserved("return",Return);
  enter_reserved("while", While);
  if( srp!=M_spell_r ) system_error("reserved word preparation");
}

int is_reserved(int spell_c[], int length){
/* checks if an unpacked spell is a reserved word:  */
/* returns its token value if it is,                */
/* returns Name if not.                             */

  int  spell[M_line], sm;  int  r, i, s;

  r= h(spell_c, length, P_r, M_r);  s= spell_rp[r];
  sm= pack(spell_c, length, spell);
  i= 0; while( i!=sm && spell[i]==spell_r[s+i] ) i= i+1;
  if( i==sm ) token= token_r[r];
  else        token= Name;
  return (token!=Name);
}

/** usual names **/
enum{ P_u=53, M_u=128 };  /* hash function parameters for usual names */

int hash[M_u];

init_names(){ int i;
  i= 0; while( i!=M_u ){ hash[i]= NIL;  i= i+1; }
  spell_index= 0;
}

int find(int spell_c[], int length){
/* finds the position in spell_table of an unpacked spell. */
/* registers the spell if not yet registered.              */

  int spell[M_line], sm;  int  h0, f, r, i;
  enum{ sentinel=0x7FFFFFFF }; /* for table lookup */

  h0= h(spell_c, length, P_u, M_u);  f= hash[h0];
  sm= pack(spell_c, length, spell);  spell[sm]= sentinel;
  i= 0;
  while( f!=NIL && spell[i]!=sentinel ){
    i= 0; while( spell[i]==spell_table[f+spell_p+i] ) i= i+1;
    r= f;  f= spell_table[f+next_p];
  }
  if( spell[i]==sentinel )  return r;
  if( spell_index+spell_p+sm>M_spell_table )
    system_error("spell_table overflow");
  r= spell_index;  
  spell_table[r+id_p]= 0;
  spell_table[r+next_p]= hash[h0];  hash[h0]= r;
  i= 0; while( i!=sm ){ spell_table[r+spell_p+i]= spell[i]; i= i+1; }
  spell_index= spell_index+spell_p+sm;
  return r;
}

/**** characterization ****/

enum{ SPACE, ONE, TWO, LETTER, H_LETTER, O_DIGIT, DIGIT };
 /*  SPACE: space, new line, etc.                                     */
 /*  ONE:   +, -, etc., which forms a token by itself.                */
 /*  TWO:   <, =, etc., which forms a token by itself or              */
 /*                           forms a token with the next character.  */
 /*  LETTER: lower-case, upper-case letters and _; except             */
 /*  H_LETTER: a-f and A-F, which are used also as hexadecimal digits.*/
 /*  O_DIGIT: 0-7, which are used as octal digits.                    */
 /*  DIGIT:   8, 9                                                    */
enum{ p0=0x1, p1=0x100, p2=0x10000, p3=0x1000000 };
 /*  positioning for packup representation  */
 /*  SPACE*p3                                       */
 /*  ONE  *p3                            + token*p0 */
 /*  TWO  *p3 + token'*p2 + next-char*p1 + token*p0 */
 /*  kind *p3                            + value*p0 */
 /*     (kind= LETTER, H_LETTER, O_DITIT, DIGIT)    */
int char_type[M_char];

enum{ ERR=-3, HEX=-2, OCT=-1 };
int esc_value[M_char];
 /* character value in escaped character representation */
 /* those values are non-negative;                      */
 /* negative value indicates need of special care       */

set_ctype(int c, int kind, int token_n, int char_n, int token){
 /* helper function used by init_ctype                      */
 /*  char_type[c]= <kind, token_n, char_n, token> (packup)  */

 char_type[c]=kind*p3+token_n*p2+char_n*p1+token*p0;
}
init_ctype(){ int c;  enum{ _ =0 };
  /* sets up char_type and esc_value */

  c= 0; while( c!=M_char ){ set_ctype(c, ONE,_,_,Nontoken); c= c+1; }
  c= 'a'; while( c<='f' ){ set_ctype(c, H_LETTER,_,_,c-'a'+10); c= c+1; }
  c= 'g'; while( c<='z' ){ set_ctype(c, LETTER,_,_,_); c= c+1; }
  c= 'A'; while( c<='F' ){ set_ctype(c, H_LETTER,_,_,c-'A'+10); c= c+1; }
  c= 'G'; while( c<='Z' ){ set_ctype(c, LETTER,_,_,_); c= c+1; }
  c= '0'; while( c<='7' ){ set_ctype(c, O_DIGIT,_,_,c-'0'); c= c+1; }
  c= '8'; while( c<='9' ){ set_ctype(c, DIGIT,_,_,c-'0'); c= c+1; }
  set_ctype('_',  LETTER,_,_,_);
  set_ctype(EOFC, ONE,_,_,Endfile);
  set_ctype(' ',  SPACE,_,_,_); set_ctype('\n', SPACE,_,_,_);
  set_ctype('\r', SPACE,_,_,_); set_ctype('\t', SPACE,_,_,_);
  set_ctype('\v', SPACE,_,_,_); set_ctype('\f', SPACE,_,_,_);
  set_ctype('(', ONE,_,_,Lpar);     set_ctype(')', ONE,_,_,Rpar);
  set_ctype('[', ONE,_,_,Lbracket); set_ctype(']', ONE,_,_,Rbracket);
  set_ctype('{', ONE,_,_,Lbrace);   set_ctype('}', ONE,_,_,Rbrace);
  set_ctype(',', ONE,_,_,Comma);    set_ctype(';', ONE,_,_,Semicolon);
  set_ctype('+', ONE,_,_,Plus);     set_ctype('-', ONE,_,_,Minus);
  set_ctype('*', ONE,_,_,Times);    set_ctype('%', ONE,_,_,Remainder);
  set_ctype('"', ONE,_,_,String);   set_ctype('\'',ONE,_,_,Character);
  set_ctype('=', TWO, Equ,'=', Becomes);
  set_ctype('|', TWO, Or, '|', Nontoken);
  set_ctype('&', TWO, And,'&', Amper);
  set_ctype('!', TWO, Neq,'=', Not);
  set_ctype('<', TWO, Leq,'=', Les);
  set_ctype('>', TWO, Geq,'=', Grat);
  set_ctype('/', TWO, Comment,'*', Divide);

  c= 0; while( c!=M_char ){ esc_value[c]= c; c= c+1; }
  c= '0'; while( c<='7' ){ esc_value[c]= OCT; c= c+1; }
  esc_value['x']= esc_value['X']= HEX;
  esc_value[EOFC]= esc_value['\n']= ERR;
  esc_value['a']= 0x07; /* \a  alert(BEL) */
  esc_value['b']= 0x08; /* \b  back space(BS) */
  esc_value['f']= 0x0C; /* \f  form feed(FF) */
  esc_value['n']= 0x0A; /* \n  new line(LF) */
  esc_value['r']= 0x0D; /* \r  carriage return(CR) */
  esc_value['t']= 0x09; /* \t  horizontal tab(HT) */
  esc_value['v']= 0x0B; /* \v  vertical tab(VT) */
}



/**** integer constant ****/

/*  integer-constant = decimal | octal | hexadecimal                    */
/*  decimal     = non-zero { digit }                                    */
/*  octal       = '0' { octal-digit }                                   */
/*  hexadecimal = '0' ('x'|'X') hexadecimal-digit { hexadecimal-digit } */
integer_constant(){
 /* ch: digit,  token= Const */

  value= 0;
  if( ch!='0' ){ /* decimal */
    while( char_type[ch]/p3 >= O_DIGIT ){
      value= value*10 + ch-'0';  get_char();
    }
  }else{
    get_char();
    if( esc_value[ch]==HEX ){ /* hexadecimal */
      get_char();
      while( char_type[ch]/p3 >= H_LETTER ){
        value= value*0x10 + char_type[ch]%0x10;  get_char();
      }
    }else{ /* octal */
      while( char_type[ch]/p3 == O_DIGIT ){
        value= value*010 + char_type[ch]%010;  get_char();
      }
    }
  }
}

/**** character constant ****/

/*  character-constant = ''' ( cahracter-c | escaped-chracter ) '''        */
/*  character-c:: any character other than '\' and newline                 */
/*  escaped-character  = simple-escape | octal-escape | hexadecimal-escape */
/*  octal-escape = '\' octal-digit [ octal-digit [ octal-digit ]]          */
/*  hexadecimal-escape = '\' ('x'|'X') hexadecimal-degit [hexadecimal-digit] */
/*  simple-escape: '\' followed by a character other then one shown above  */

int escaped_character(){ int v;
 /* ch: '\' */

  get_char();  v= esc_value[ch];
  if( v < 0 ){
    if( v==OCT ){ int j;  /* octal-escape */
      v= char_type[ch]%010; j= 1;  get_char();
      while( char_type[ch]/p3 == O_DIGIT ){
        v= v*010 + char_type[ch]%010; j= j+1;  get_char();
      }
      if( j>3 )  token= Nontoken;
    }else
    if( v==HEX ){ int j;  /* hexadecimal-escape */
      get_char();  v= 0;  j= 0;
      while( char_type[ch]/p3 >= H_LETTER ){
        v= v*0x10 + char_type[ch]%0x10; j= j+1;  get_char();
      }
      if( j==0 || j>2 )  token= Nontoken;
    }else{ /* illegal character */
      token= Nontoken;  v= 0;
    }
  }else{ /* simple-escape */
    get_char();
  }
  return v;
}

character_constant(){
 /* ch: one following ''',  token= Character */
 /* sets value with the character code       */

  if( ch==EOFC || ch=='\n' || ch=='\'' ){
    token= Nontoken;
  }else
  if( ch=='\\' ){ /* escaped-character */
    value= escaped_character();
  }else{
    value= ch;  get_char();
  }
  if( ch=='\'' )  get_char();
  else  token= Nontoken;
}
    
/**** string constant ****/

/*  string-constant = '"' { character-s | escaped-character } '"' */
/*  character-s:  any character other than '"' and newline        */

string_constant(){
 /* ch: character following '"', token= String */

  int spell_c[M_line_c], scm;

  scm= 0;
  while( ch!=EOFC && ch!='\n' && ch!='"' ){int w;
    if( ch!='\\'){
      w= ch;  get_char();
    }else
      w= escaped_character();
    spell_c[scm]= w;  scm= scm+1;
  }
  if( ch=='"' )  get_char(); 
  else  token= Nontoken;
  pack(spell_c, scm, word);
}

/**** comment ****/

/*  comment:  begins with '/''*' and ends with '*''/'      */
/*            may extend to several lines                  */

comment(){
 /* ch: character following '/''*', token= Comment  */

  while( ch!=EOFC && ch!='*' )  get_char();
  while( ch=='*' ){
    get_char();
    if( ch=='/'){
      get_char();   return;
    }
    while( ch!=EOFC && ch!='*' ) get_char();
  }
  ch= Endfile;
}

/**** name and reserved word ****/

/*  name = letter { digit | letter }                       */
/*  letter:  lower-case and upper-case letters and '_'     */
/*  digit:   0 - 9                                         */
/*  following are reserved and used for special purposes   */
/*    else  enum  if  int  return  while                   */

identifier(){
  /* ch: letter,  token= Name */

  int  spell_c[M_line_c], scm;

  scm= 0;
  while( char_type[ch]/p3 >= LETTER ){
    spell_c[scm]= ch;  scm= scm+1;  get_char();
  }
  if( is_reserved(spell_c, scm) )  return;
  spell= find(spell_c, scm);
}

/**** token(lexical element)  ****/
get_token(){
 /* invariant:  ch holds the next character available */

  while( char_type[ch]/p3 == SPACE )  get_char();
  if( char_type[ch]/p3 < LETTER ){ /* ONE or TWO */
    token= char_type[ch]%p1;
    if( char_type[ch]/p3 == ONE ){
      if( token!=Endfile )  get_char();
      if( token==String ){ string_constant(); return; }
      if( token==Character ){ character_constant(); return; }
    }else{ int c;
      c= ch;  get_char();
      if( ch==(char_type[c]/p1)%p1 ){
        token= (char_type[c]/p2)%p1;  get_char();
      }
      if( token==Comment ){ comment();  return; }
    }
  }else
  if( char_type[ch]/p3 >= O_DIGIT ){
    token= Const;  integer_constant();
  }else{
    token= Name;  identifier();
  }
}

init_token(){
  init_reserved();
  init_names();
  init_ctype();
  init_char();  get_char();
}





/**** tokenDriver ****/

int representation[100], rprm;
int link_repr[Comment+1];

set_repr(int token, int repr[]){
  int repr_c[20], rprc;
  
  rprc= unpack(repr, repr_c);
  link_repr[token]= rprm;
  rprm= rprm + pack(repr_c, rprc, &representation[rprm]);
}

init_repr(){
  rprm= 0;
  set_repr(Else, "else");
  set_repr(Enum, "enum");
  set_repr(If,   "if");
  set_repr(Int,  "int");
  set_repr(Return, "return");
  set_repr(While,"while");
  set_repr(Name, "Name");
  set_repr(Const,"integer");
  set_repr(Character, "character");
  set_repr(String,"string");
  set_repr(Plus, "+");
  set_repr(Minus, "-");
  set_repr(Not, "!");
  set_repr(Amper,"&");
  set_repr(Times, "*");
  set_repr(Divide, "/");
  set_repr(Remainder, "%");
  set_repr(Les, "<");
  set_repr(Leq, "<=");
  set_repr(Grat, ">");
  set_repr(Geq, ">=");
  set_repr(Equ, "==");
  set_repr(Neq, "!=");
  set_repr(And, "&&");
  set_repr(Or,  "||");
  set_repr(Becomes,"=");
  set_repr(Comma, ",");
  set_repr(Semicolon, ";");
  set_repr(Lpar, "(");
  set_repr(Rpar, ")");
  set_repr(Lbracket, "[");
  set_repr(Rbracket, "]");
  set_repr(Lbrace, "{");
  set_repr(Rbrace, "}");
  set_repr(Nontoken, "???");
  set_repr(Endfile, "EOF");
  set_repr(Comment, "comment");
}

main(){
  init_token();
  init_repr();
  get_token();
  while( token!=Endfile ){
    fputs(&representation[link_repr[token]], stdout);
    if( token==Name){
      fputs(": ", stdout);
      fputs(&spell_table[spell+spell_p], stdout);
    }else
    if( token==Const || token==Character ){
      fputs(": ", stdout);  decimal(value, stdout);
    }else
    if( token==String ){
      fputs(": ", stdout);  fputs(word, stdout);
    }
    fputs("\n", stdout);
    get_token(); 
  }
  fputs("-------\nEND\n", stdout);
}




