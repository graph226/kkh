/**** files and options ****/
int  f_source;  /* source file */
int  f_object;  /* object file */
int  verbose;   /* mode indicator */

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
int  error_count;

error(int message[]){
/* output a message */
  decimal(line_no, stderr); fputs("::ERROR::", stderr);
  fputs(message, stderr);  fputc('\n', stderr);
  error_count= error_count+1;
}

init_error(){
/* error_count initialization */
  error_count= 0;
}


system_error(int message[]){
/* output a message and aborts the compilation */

  decimal(line_no, stderr); fputs("::SYSTEM::", stderr);
  fputs(message, stderr); fputc('\0', stderr);
  exit(-1);
}


/**** token output ****/
enum{
  Nontoken,
  Times, Divide, Remainder,
  Les, Leq, Grat, Geq,
  Equ, Neq,
  And, Or,
  Becomes,
  Lbracket,
  Comma, Rpar, Rbracket,
  Else, Rbrace, Semicolon,
  If, Return, While, Lbrace,
  Lpar, Plus, Minus, Not, Amper,
  Const, Character, String,
  Name, Int, Enum,
  Endfile, Comment
};

int first_decl(int token){
  return (Name<=token && token<=Enum);
}
int first_stmt(int token){
  return (Semicolon<=token && token<=Name);
}
int first_expr(int token){
  return (Lpar<=token && token<=Name);
}

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
      if( token==Comment ){ comment();  get_token(); return; }
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


/*************************************/
/**** semantical analysis: tools  ****/
/*************************************/

/*** kind of objects ***/

enum{ 
  none,      /* unknown: non-declared     */   
  constant,  /* constant (known r-value)  */
  variable,  /* varibale (l-value)        */
  expr,      /* r-value (run time)        */
  array,     /* array (l-value)           */
  function,  /* function (l-value)        */
  M_kind
}; 
enum{
  p_null,    /* parameter */
  p_val,     /*   value */
  p_arr,     /*   array */
  M_p
};
/* Each function has its parameter profile: */
/*   "(p1, ..., pn)"                        */
/*  <=> V(p1)*(M_p)^(n-1)                   */
/*      + V(p2)*(M_p)^(n-2)                 */
/*      + .....                             */
/*      + V(pn)*(M_p)^(n-n),                */
/* where V("int")=p_val, V("int[]")=p_arr.  */
/* Note that "()" <=> 0.                    */
/* A function is registered with the kind:  */
/*     'function'+profile                   */

/*** memory allocation (for a function block) ***/
int next_addr;   /* next available address for allocation  */ 
int last_addr;   /* total size of the allocated area       */
int link_addr;   /* total size of link and parameter block */
int level;       /* local/global */

/*** name table structure ***/
enum{ M_name_table=2000 };
int name_table[M_name_table];
int entry_point;
  /* Each declared name is registered in "name_table" */
  /* as an entry.  "entry_point" holds the next       */
  /* avairable point.  An entry consists of:          */ 
  enum{
    nextp,   /* link to the next entry of the same spell */
    spellp,  /* backward link to the spell_table         */
    kindp,   /* declared kind                            */
    addrp,   /* value of the object                      */
    M_entry  /*    :size of an entry                     */
  };
  enum{ undefined= 0x40000000 };
  /* Indicator for a function entry showing  */
  /* it is declared but not defined yet.     */
  enum{ indirect= 0x30000000, local= 0x20000000, 
        global= 0x10000000, text= 0x00000000 };
  /* indicates in which area the address belongs to:   */
  /*   indirect: to the stack - indirect address       */
  /*   local:    to the stack                          */
  /*   global:   to the data area                      */
  /*   text:     to the program area                   */

  /* Name entries are separated by a header which shows */
  /* nesting of the blocks.                             */
  enum{
    outp,       /* link to the outer block */
    old_addr,   /* next_addr reservation   */
    M_header    /*    :size of a header    */
  };
  
/*** error handling ***/

error_name(int message[], int e){ int m[M_line_c], l;
  l= unpack(message, m);
  l= l+ unpack(&spell_table[name_table[e+spellp]+spell_p], &m[l]);
  { int mp[M_line];
    pack(m, l, mp);
    error(mp);
  }
}


int current_block;
  /* "current_block" points to the header corresponding */
  /* to the current block.                              */
push_block(){ int e;
  if( entry_point+M_header>M_name_table )
    system_error("name table overflow");
  e= entry_point;  entry_point= entry_point+M_header;
  name_table[e+outp]= current_block;
  name_table[e+old_addr]= next_addr;
  current_block= e;
}
pop_block(){ int e;
  e= current_block+M_header;
  while( e!=entry_point ){ int s;
    s= name_table[e+spellp];
    spell_table[s+id_p]= name_table[e+nextp];
    e= e+M_entry;
  }
  e= name_table[current_block+outp];
  next_addr= name_table[current_block+old_addr];
  if( e<0 ) system_error("name tabel underflow");
  entry_point= current_block;
  current_block= e;
}

int enter(int spell, int kind, int addr){ int e;
/* registers an entry into "name_table" */

  if( entry_point+M_entry > M_name_table )
    system_error("name table overflow");
  e= entry_point;  entry_point= entry_point+M_entry;
  name_table[e+nextp]= spell_table[spell+id_p];
    spell_table[spell+id_p]= e;
  name_table[e+spellp]= spell;
  name_table[e+kindp]= kind;
  name_table[e+addrp]= addr;
  return e;
}

int declare(int spell){ int e;
/* finds an entry in the current block for the spell. */
/* if none, registers an entry in the current block,  */
/* with kind=none.                                    */

  e= spell_table[spell+id_p];
  if( e < current_block )  e= enter(spell, none, 0);
  return e;
}

int retrieve(int spell){ int e;
/* finds an entry in the name table for the spell. */
/* if none, declare it in the current block.       */

  e= spell_table[spell+id_p];
  if( e == 0 ){
    e= declare(spell);
    error_name("undefined name: ", e);
  }
  return  e;
}
  
int repr_kind[M_kind];  /* representation for a kind */
init_repr_kind(){
  repr_kind[none]= '?';
  repr_kind[constant]= 'C';
  repr_kind[variable]= 'V';
  repr_kind[expr]= 'e';
  repr_kind[array]= 'A';
  repr_kind[function]= 'F';
}

print_args(int profile){ int a;
  if( profile>=M_p ){
    print_args(profile/M_p); fputc(',', stdout);
  }
  a= profile%M_p;
  fputs("int", stdout);
  if( a==p_arr ) fputs("[]", stdout);
}
print_profile(int profile){
/* prints a profile */

  fputc('(', stdout);
  if( profile!=0 ) print_args(profile);
  fputc(')', stdout);
}
print_attributes(int e){ int k, k1, a;
/* prints attributes */

  k= k1= name_table[e+kindp]; a= name_table[e+addrp];
  if( k>function ) k1= function;
  fputs(" [ ", stdout); 
    fputc(repr_kind[k1], stdout);
    if( k1==function )  print_profile(k-function);
  fputs(" ] ", stdout);
  if( k==constant )
    decimal(a, stdout);
  else
  if( k==variable || k==array ){
    decimal(a%global, stdout);
    if( a>=indirect )  fputs("(I)", stdout); else
    if( a>=local    )  fputs("(L)", stdout); else
    if( a>=global   )  fputs("(G)", stdout); else
    if( a>=text     )  fputs("(P)", stdout);
  }else
  if( k1==function ){
    if( name_table[e+addrp]>=undefined ) fputs("-", stdout);
    decimal(name_table[e+addrp]%global, stdout);
  }
}  
print_name(int e){
/* print name with its attributes */

  fputs(&spell_table[name_table[e+spellp]+spell_p], stdout);
  print_attributes(e);
  fputc('\n', stdout);
}
print_current_block(int spaces){ int e;
  e= current_block+M_header;
  while( e!=entry_point ){ int s; s= spaces;
    while( s!=0 ){
      fputc(' ', stdout);  s= s-1;
    }
    print_name(e);
    e= e+M_entry;
  }
}
  
int enter_std(int spell[], int addr, int kind){ int s;
/* registers a standard entry */

  { int spell_c[M_line_c], length;
    length= unpack(spell, spell_c);
    s= find(spell_c, length);
  }
  return enter(s, kind, addr);
}
int f0(){ return function + 0; }
int f1(int p){ return function+(p); }
int f2(int p1, int p2){ return  function+(p1 *M_p + p2); }
int f3(int p1, int p2, int p3){
  return  function+(( p1 *M_p + p2 )*M_p + p3);
}
init_std(){
/* initializes standard names */

  enter_std("exit",   0, f1(p_val));
  enter_std("get",    1, f0());
  enter_std("put",    2, f1(p_val));
  enter_std("err",    3, f1(p_val));
  enter_std("fopen",  4, f2(p_arr,p_arr));
  enter_std("fclose", 5, f1(p_val));
  enter_std("fgetc",  6, f1(p_val));
  enter_std("fputc",  7, f2(p_val,p_val));
  enter_std("fgets",  8, f3(p_arr,p_val,p_val));
  enter_std("fputs",  9, f2(p_arr,p_val));
  enter_std("pack",  10, f3(p_arr,p_val,p_arr));
  enter_std("unpack",11, f2(p_arr,p_arr));
  enter_std("EOF",   -1, constant);
  enter_std("NULL",   0, constant);
  enter_std("stdin",  1, constant);
  enter_std("stdout", 2, constant);
  enter_std("stderr", 3, constant);
  enter_std("args",   0, array);
}




/********************************/
/**** code generation: tools ****/
/********************************/
/* object code consists of:       */
/*  directives - to the loader    */
/*  instrucitons - of the program */

int pc;  /* program counter */
enum { origin= 0x10 };

directive(int dir[], int addr){
  fputs(dir, f_object);  fputc(' ', f_object);
    decimal(addr, f_object);  fputc('\n', f_object);
}


/* for some instructions, we need to fix them up */
/* when their address part content is defined.   */
/*   fixed_up(a, x)                              */
/*     fixes up the instruction at the address a */
/*     with x as its address part content        */
/*   set_label()                                 */
/*     returns the current address               */

int set_label(){
  directive("L", pc);
  return pc;
}
fixed_up(int at, int addr){
  fputs("F", f_object); fputc(' ', f_object);
    decimal(at, f_object); fputc(' ', f_object);
    decimal(addr,f_object); fputc('\n', f_object);
}

/** gen(op, addr):                        **/
/**  generates an instrunction (op, addr) **/

gen(int op[], int addr){
  fputc(' ', f_object);
    fputs(op, f_object); fputc(' ', f_object);
    decimal(addr, f_object); fputc('\n', f_object);
  pc= pc+1;
}

/* gen_str(c1,c2,c3,c4):                    */
/*  generates a word containing a character */
/*  string of c1,c2,c3 and c4.              */

gen_str(int c1, int c2, int c3, int c4){
  fputc(' ', f_object);
    fputs("DS", f_object); fputc(' ', f_object);
    decimal(c1, f_object); fputc(' ', f_object);
    decimal(c2, f_object); fputc(' ', f_object);
    decimal(c3, f_object); fputc(' ', f_object);
    decimal(c4, f_object); fputc('\n', f_object);
  pc= pc+1;
}

gen_op(int op[]){
  gen(op, 0);
}

gen_lv(int val){ 
  if( val>=0 )
    gen("LV", val);
  else{int a0, a1; 
    a0= set_label(); gen("J", 0);
    a1= set_label(); gen("DC", val);
    fixed_up(a0, set_label());
    gen("LP", a1);
  }
}

init_gen(){
  pc= origin;  set_label();
}

/***************************/
/***** syntax analysis *****/
/***************************/

/**** error handling ****/

missing(int token_repr[]){
/* error: when a token is missing */
  int packed[M_line], unpacked[M_line_c], l;

  l= unpack("missing ", unpacked);
  l= unpack(token_repr, &unpacked[l])+l;
  pack(unpacked, l, packed);  error(packed);
}

skip_to(int target){
  if( token<target ){
    error("some tokens skipped");
    while( token<target ) get_token();
  }
}


/**** expressions ****/
/** each processing function returns the kind  **/
/** of the expression just processed           **/

int expression(); /* function declaration */

eval(int kind){
/* checks if kind is convertible to an r-value */

  if( kind >= array ) error("r-value exprected");
  if( kind==variable ) gen_op("DER");
}

int primary(){ int k;
  if( token==Name ){ int e;
    e= retrieve(spell);  get_token();
    k= name_table[e+kindp];
    if( k==constant )
      gen_lv(name_table[e+addrp]);
    else{int l, a;
      l= name_table[e+addrp];
      if( l<0 )  system_error("negaive address");
      a= l%global;
      if( l>=undefined ) l= l-undefined;
      if( l>=indirect )  gen("L",   a);  else
      if( l>=local )     gen("LA",  a);  else
      if( l>=global )    gen("LGA", a);  else
      if( l>=text )      gen("LPA", a);
    }
  }else
  if( token==Const || token==Character ){
    gen_lv(value);
    k= constant;  get_token();
  }else
  if( token==String ){int word_c[M_line_c], l, lm, a0, a1;
    lm= unpack(word, word_c); word_c[lm]= '\0'; lm= lm+1;
    while( lm%4 !=0 ){
      word_c[lm]= '\0';  lm= lm+1;
    }
    a0= set_label();  gen("J", 0);
    a1= set_label();
    l= 0;
    while( l!=lm ){
      gen_str(word_c[l],word_c[l+1],word_c[l+2],word_c[l+3]);
      l= l+4;
    }
    fixed_up(a0, set_label());  gen("LPA", a1);
    k= array;  get_token();
  }else
  if( token==Lpar ){
    get_token();
    k= expression();
    if( token==Rpar ) get_token();  else missing(")");
  }else{
    error("not a primary"); k= none;
  }
  return k;
}

param(int kind, int kk[], int i){
  if( i>0 ){
    if( kk[i-1]==p_val ){
      if( kind==variable )  gen_op("DER");
      if( kind>=array ) error("r-value expected as an argument");
    }
    if( kk[i-1]==p_arr ){
      if( kind!=array && kind!=none )
        error("array expected as an argument");
    }
  }
}

int suffixed(){ int k;
  k= primary();
  if( token==Lbracket ){
    if( k!=array && k!=none ) error("index for non-array");
    get_token();
    eval(expression());  gen_op("+");
    if( token==Rbracket ) get_token(); else missing("]");
    k= variable;
  }else
  if( token==Lpar ){ int at[20], n, i;
    if( k<function && k!=none ) error("call for non-function");
    n= 0;
    if( k>=function ){ int w;
      w= k-function;
      while( w!=0 ){
        at[n]= w%M_p;  w= w/M_p;
        n= n+1;
      }
    }
    get_token();  i= n;
    if( token!=Rpar ){ 
      param(expression(), at, i);  i= i-1;
      while( token==Comma ){
        get_token();
        param(expression(), at, i);  i= i-1;
      }
    }
    if( token==Rpar ) get_token();  else  missing(")");
    if( k>=function )
      if( i!=0 )
        error("number of parameters doesn't match");
    gen("CAL", n);
    k= expr;
  }
  return k;
}

int prefixed(){ int k;
  if( token==Plus 
   || token==Minus || token==Not ){ int t; t= token;
    get_token();
    eval(prefixed());
      if( t==Minus ) gen_op("NEG");
      if( t==Not )   gen_op("!");
    k= expr;
  }else
  if( token==Amper ){
    get_token();
    k= prefixed();
    if( k!=variable && k!=none ) error("& for non-variable");
    k= array;
  }else{
    k= suffixed();
  }
  return k;
}

int arith_term(){ int k;
  k= prefixed();
  while( token==Times 
      || token==Divide || token==Remainder ){int t; t= token;
    eval(k);  k= expr;
    get_token();
    eval(prefixed());
      if( t==Times )      gen_op("*");
      if( t==Divide )     gen_op("/");
      if( t==Remainder )  gen_op("%");
  }
  return k;
}

int arithmetic(){ int k;
  k= arith_term();
  while( token==Plus || token==Minus ){int t; t= token;
    eval(k);  k= expr;
    get_token();
    eval(arith_term());
      if( t==Plus )   gen_op("+");
      if( t==Minus )  gen_op("-");
  }
  return k;
}

int comparison(){ int k;
  k= arithmetic();
  while( token==Les  || token==Leq 
      || token==Grat || token==Geq ){int t; t= token;
    eval(k);  k= expr;
    get_token();
    eval(arithmetic());
      if( t==Les )   gen_op("<");
      if( t==Leq )   gen_op("<=");
      if( t==Grat )  gen_op(">");
      if( t==Geq )   gen_op(">=");
  }
  return k;
}

int equality(){ int k;
  k= comparison();
  while( token==Equ || token==Neq ){int t; t= token;
    eval(k);  k= expr;
    get_token();
    eval(comparison());
      if( t==Equ )  gen_op("==");
      if( t==Neq )  gen_op("!=");
  }
  return k;
}

int logical_term(){ int k;
  k= equality();
  while( token==And ){
    eval(k);  k= expr;
    get_token();
    eval(equality());
      gen_op("&&");
  }
  return k;
}

int logical(){ int k;
  k= logical_term();
  while( token==Or ){
    eval(k);  k=expr;
    get_token();
    eval(logical_term());
      gen_op("||");
  }
  return k;
}

int expression(){ int k, k1;
  k= logical();
  if( token==Becomes ){int n;
    k1= k;  k= expr;  n= 0;
    while( token==Becomes ){
      if( k1!=variable && k1!=none )
        error("l-value expected");
      get_token();
      k1= logical();  n= n+1;
    }
    eval(k1);
      while( n!=0 ){
        gen_op("TA");  n= n-1;
      }
  }
  skip_to(Comma);
  return k;
}

/**** constant expression ****/
/****  each processing function returns its value ****/
int  const_expr();

int  const_primary(){ int v;
  if( token==Name ){ int e, k;
    e= retrieve(spell);  get_token();
    k= name_table[e+kindp];
    if( k!=constant && k!=none ) error("not a constant primary");
    if( k==constant ) v= name_table[e+addrp];  else v= 1;
  }else
  if( token==Const || token==Character ){
    v= value;  get_token();
  }else
  if( token==Lpar ){
    get_token();
    v= const_expr();
    if( token==Rpar ) get_token();  else missing(")");
  }else{
    error("not a constant primary");
    v= 1;
  }
  return v;
}

int const_prefixed(){ int v;
  if( token==Plus || token==Minus ){ int t;
    t= token;  get_token();
    v= const_prefixed();
         if( t==Plus )  v= +v;
    else if( t==Minus ) v= -v;
  }else{
    v= const_primary();
  }
  return v;
}

int nz(int v){
/* checks if the divisor v is 0 */

  if( v==0 ){
    error("0 divisor in a constant expression");
    v= 1;
  }
  return v;
}
int const_term(){ int v;
  v= const_prefixed();
  while( token==Times 
      || token==Divide || token==Remainder ){ int t, v1;
    t= token;  get_token();
    v1= const_prefixed();
         if( t==Times )     v= v*v1;
         if( t==Divide )    v= v/nz(v1);
         if( t==Remainder ) v= v%nz(v1);
  }
  return v;
}

int const_expr(){ int v;
  v= const_term();
  while( token==Plus || token==Minus ){ int t, v1;
    t= token;  get_token();
    v1= const_term();
         if( t==Plus )   v= v+v1;
    else if( t==Minus )  v= v-v1;
  }
  skip_to(Comma);
  return v;
}


/**** declarations ****/

declarator(int e){
  if( name_table[e+kindp]!=none ) 
    error_name("double declaration: ", e);
  if( token==Lbracket ){ int v;
    get_token();
    v= const_expr();
    if( v<=0 ) error("array size: positive value expected");
    if( token==Rbracket ) get_token(); else missing("]");
    name_table[e+kindp]= array;
    name_table[e+addrp]= level+next_addr;  
    next_addr= next_addr+v;
  }else{
    name_table[e+kindp]= variable;
    name_table[e+addrp]= level+next_addr;
    next_addr= next_addr+1;
  }
  skip_to(Comma);
}

var_decl(int e){
  declarator(e);
  while( token==Comma ){
    get_token();
    if( token==Name ){
      e= declare(spell);  get_token();
      declarator(e);
    }else{
      missing("a name");  skip_to(Comma);
    }
  }
  if( token==Semicolon )  get_token(); else missing(";");
  skip_to(Rbrace);
}

int enum_declarator(int v){
  if( token==Name ){ int e;
    e= declare(spell);  get_token();
    if( name_table[e+kindp]!=none ) 
      error_name("double declaration: ", e);
    if( token==Becomes ){
      get_token();
      v= const_expr();
    }
    name_table[e+kindp]= constant;
    name_table[e+addrp]= v;
  }else{
    missing("a name");
  }
  skip_to(Comma);  return v;
}

enum_decl(){ int v;
  get_token();
  if( token==Lbrace )  get_token(); else missing("{");
  v= enum_declarator(0)+1;
  while( token==Comma ){
    get_token();
    v= enum_declarator(v)+1;
  }
  if( token==Rbrace ) get_token(); else missing("}");
  if( token==Semicolon ) get_token(); else missing(";");
  skip_to(Rbrace);
}


/**** statements  ****/
statement();  /* function declaration */

expr_statement(){
  expression();
  if( token==Semicolon ) get_token(); else missing(";"); 
    gen_op("POP");
}

if_statement(){int a0;
  get_token();
  if( token==Lpar ) get_token(); else missing("(");
  eval(expression()); 
  if( token==Rpar ) get_token(); else missing(")");
    a0= set_label();  gen("JF", 0);
  statement();
  if( token==Else ){int e0;
      e0= set_label();  gen("J", 0);
      fixed_up(a0, set_label());  a0= e0;
    get_token();
    statement();
  }
    fixed_up(a0, set_label());
}

while_statement(){int a0, a1;
  get_token();  a0= set_label();
  if( token==Lpar ) get_token(); else missing("(");
  eval(expression());
    a1= set_label();  gen("JF", 0);
  if( token==Rpar ) get_token(); else missing(")");
  statement();
    gen("J", a0);
    fixed_up(a1, set_label());
}

return_statement(){
  get_token();
  if( first_expr(token) ){
    eval(expression()); 
  }else
    gen_lv(0);
  if( token==Semicolon ) get_token(); else missing(";");
    gen("RET", link_addr);
}

block(){
  push_block();
  get_token();
  while( token==Int || token==Enum ){
    if( token==Int ){ int e;
      get_token();
      if( token==Name ){
        e= declare(spell);  get_token();
        var_decl(e);
      }else{
        missing("a name");  skip_to(Rbrace);
      }
    }else{
      enum_decl();
    }
  }
  skip_to(Rbrace);
  while( first_stmt(token) ){
    statement(); skip_to(Rbrace);
  }
  if( token==Rbrace ) get_token(); else missing("}");
  if( next_addr>last_addr )  last_addr= next_addr;
  pop_block();
}

statement(){
  if( token==Semicolon ){
    get_token();  /* empty-statement */
  }else
  if( first_expr(token) ){
    expr_statement();
  }else
  if( token==If ){
    if_statement();
  }else
  if( token==While ){
    while_statement();
  }else
  if( token==Return ){
    return_statement();
  }else
  if( token==Lbrace ){
    block();
  }else{
    error("not a statement");
  }
  skip_to(Else);
}


/**** fuction declarations and definitions ****/

enum{ n_param, n_int, n_name };

int parameter(int c[]){ int s, p, e;
  s= 0; p= p_val; e= 0;
  if( token==Int  ){ 
    s= 1;  c[n_int]= c[n_int]+1;   get_token(); 
  }
  if( token==Name ){ 
    s= 1;  c[n_name]= c[n_name]+1; 
    e= declare(spell);
    if( name_table[e+kindp]!=none ) 
      error_name("double defined parameter: ", e);
    get_token(); 
  }
  if( token==Lbracket ){
    p= p_arr;
    if( s==0 ) error("[ without int or name");
    get_token();
    if( token==Rbracket ) get_token(); else missing("]");
  }
  c[n_param]= c[n_param]+1;
  if( e!=0 ){
    if( p==p_arr ){
      name_table[e+kindp]= array;
      name_table[e+addrp]= indirect+next_addr;
        next_addr= next_addr+1;
    }else{
      name_table[e+kindp]= variable;
      name_table[e+addrp]= local+next_addr;
        next_addr= next_addr+1;
    }
  }
  return  p;
}

func_decl(int e){ int c[n_name+1]; int prof;
  push_block();  /* parameter block */
  next_addr= last_addr= 0;  level= local;

  c[n_param]= c[n_int]= c[n_name]= prof= 0;
  if( token==Lpar ) get_token(); else missing("(");
  if( token!=Rpar ){
    prof= parameter(c); 
    while( token==Comma ){
      get_token();
      prof= prof*M_p + parameter(c); 
    }
  }
  if( token==Rpar ) get_token(); else missing(")");
  if( token==Semicolon ){
    if( c[n_param]!=c[n_int] ) 
      error("missing int's in declaration");
    get_token();
    if( name_table[e+kindp]!=none ) 
      error_name("double defined function: ", e);
    else{
      name_table[e+kindp]= function+prof;
      name_table[e+addrp]= undefined+set_label(); gen("J", 0);
      if( verbose ){
        fputs("DCL: ", stdout);  print_name(e);
      }
    }
  }else
  if( token==Lbrace ){
    if( c[n_param]!=c[n_name] ) 
      error("missing names for parameter");
    if( name_table[e+kindp]==none ){
      name_table[e+kindp]= function+prof;
      name_table[e+addrp]= set_label();
      if( verbose ){
        fputs("DCL: ", stdout);  print_name(e);
        print_current_block(5);
      }
    }else
    if( name_table[e+kindp]>=function ){
      if( prof!=name_table[e+kindp]-function )
        error_name("mismatched profile for definition: ", e);
      if( name_table[e+addrp]>=undefined ){int a;
        a= set_label();
        fixed_up(name_table[e+addrp]-undefined, a);
        name_table[e+addrp]= a;
      }else{
        error_name("redefinition for function: ", e);
      }
      if( verbose ){
        fputs("DEF: ", stdout); print_name(e);
        print_current_block(5);
      }
    }else{
      error_name("double definition: ", e);
    }
    link_addr= next_addr;  next_addr= next_addr+2;
    {int a0;
      a0= set_label();  gen("SET", 0);
      block();
      fixed_up(a0, last_addr);
    }
    gen_lv(0);  gen("RET", link_addr);
  }else{
    missing("; or block");
  }
  pop_block();  level= global;
}

declaration(){
  if( token==Int ){ int e;
    get_token();
    if( token==Name ){
      e= declare(spell);  get_token();
      if( token==Lpar ){
        func_decl(e);
      }else{
        var_decl(e);
      }
    }else{
      missing("a name");
    }
  }else
  if( token==Name ){ int e;
    e= declare(spell);  get_token();
    func_decl(e);
  }else
  if( token==Enum ){
    enum_decl();
  }else{
    error("not a declaration");
  }
  skip_to(Name);
}


/**** programs ****/

program(){int ma;
  init_error(); init_token();
  init_repr_kind();
  init_gen();
  current_block= -1;  entry_point= 0;
  push_block();  init_std();  
  push_block(); ma= enter_std("main", 0, none);
  next_addr= 0;  level= global;
  get_token();

  declaration();
  while( first_decl(token) ){
    declaration();
  }

  if( token!=Endfile )
    error("tokens after a program");

  { int e;
    e= current_block+M_header;
    while( e!=entry_point ){int k;
      k= name_table[e+kindp];
      if( e==ma ){
        if( k!=function ) error("'main' not type ()");
        else 
        if( name_table[ma+addrp]>=undefined ) 
          error("undefined 'main'");
        else
          directive("E", name_table[ma+addrp]);
      }else
      if( k<function ){
        if( verbose ) print_name(e);
      }else{
        if( name_table[e+addrp]>=undefined ) 
          error_name("undefined function: ", e);
      }
      e= e+M_entry;
    }
    directive("S", next_addr);
    if( verbose ){
      fputs("program: ",stdout); decimal(pc,stdout); 
      fputs(" data: ",stdout); decimal(next_addr,stdout);
      fputc('\n',stdout);
    }
  }
}

/*********************************/
/**** command line analysis   ****/
/*********************************/

/* A command line is of the form:               */
/*   command { {RE} PAR } {RE}                  */
/* where RE stands for 'redirection':           */
/*   < fname    reads stdin from fname          */  
/*   > fname    writes stdout to fname          */
/*   >& fname   writes stderr to fname          */
/*   >> fname   appends stdout to fname         */
/*   >>& fname  appends stdout to fname         */
/* and PAR for 'parameter' for the command      */
/* which is any sequence of charaters without   */
/* blank spaces in it.                          */
/* VM handles all RE's and evokes a program     */
/* whose file name is specified by the commnad, */
/* with an array "args" containing the commnad  */
/* and all PAR's in sequence separated with a   */
/* space in a character string format.          */
/* Note that PAR should consist of:             */
/*   a-z, A-Z, 0-9,                             */
/*   ! # $ % * + . - , / : = ? [ ] ^ _ { } ~    */

/* WL processor has PAR's:                      */
/*     fname       : specifies the source file  */
/*     -[O|o] fnam : specifies the object name  */
/*     -[V|v]      : gets WL processor verbose  */
/* All PAR's are optional;                      */
/*    Default input:  stdin                     */
/*    Default object: "a.out"                   */
/* Error messages are written to stderr,        */
/* and other messages to stdout.                */

int com[100], com_l, com_p; /* unpacked command line */

init_com(int args[]){
/* initializes the com, com_l and com_p */

  com_l= unpack(args, com);
  com_p= 0;
}
int get_arg(int arg[]){ int i;
/* gets the next PAR from the com into arg, */
/* and returns its length                   */

  i= 0;
  while( com_p!=com_l && com[com_p]!=' ' ){
    arg[i]= com[com_p];
    com_p= com_p+1;  i= i+1;
  }
  if( com_p!=com_l )  com_p= com_p+1;
  return i;
}
opened(int file, int name[]){
/* checks if the file has been opened */

  if( file==NULL ){
    fputs("can't open: ", stderr);
    fputs(name, stderr);  fputs("\n", stderr);
    exit(-1);
  }
}
set_io(int args[]){ int fname[100], l, n;
/* commnad line analysis */

  verbose= 0;  f_source= stdin;  f_object= NULL;
  init_com(args);  get_arg(fname);/* command name */
  l= get_arg(fname);  n= 0;
  while( l!=0 ){
    if( fname[0]=='-' ){
      if( fname[1]=='v' || fname[1]=='V' )  verbose= 1;
      n= n-1;
    }else
    if( n==0 ){ int fn[25];
      pack(fname, l, fn);
      f_source= fopen(fn,"r"); opened(f_source, fn);
    }else
    if( n==1 ){ int fn[25];
      pack(fname, l, fn);
      f_object= fopen(fn, "w"); opened(f_object, fn);
    }
    l= get_arg(fname);  n= n+1;
  }
  if( n>2 ){
    fclose(f_source);  fclose(f_object);
    fputs("usage: wl [-v] [source [object]]\n", stderr);
    exit(-1);
  }
  if( f_object==NULL ){
    f_object= fopen("a.out", "w"); opened(f_object,"a.out");
  }
}
  
main(){
  set_io(args); /* args: commnad line */
  program();
  if( f_source!=stdin ) fclose(f_source); fclose(f_object);
  if( error_count!=0 ){
    fputs("total error: ",stderr);
     decimal(error_count, stderr); fputc('\n', stderr);
  }else{
    if( verbose ){
      /* final message, if any */
    }
  }
}

