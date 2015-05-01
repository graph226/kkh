primary(){
  if( token==Name      || token==Const 
   || token==Character || token==String ){
    get_token();
  }else
  if( token==Lpar ){
    get_token();
    expression();
    if( token==Rpar ) get_token();  else error();
  }else{
    error();
  }
}

arithmetic(){
  arith_term();
  while( token==Plus || token==Minus ){
    get_token();
    arith_term();
  }
}

logical(){
  logical_term();
  while( token==Or ){
    get_token();
    logical_term(); 
  }
 }

suffixed(){
  primary();
  if( token==Lbracket ){
    get_token();
    expression(); 
    if( token==Rbracket ) get_token(); else error();
  }else
  if( token==Lpar ){
    get_token();
    if( token!=Rpar ){
      expression();
      while( token==Comma ){
        get_token();
        expression();
      }
    }
    if( token==Rpar ) get_token();  else  error();
  }
}

comparison(){
  arithmetic();
  while( token==Les  || token==Leq 
      || token==Grat || token==Geq ){
    get_token();
    arithmetic();
  }
}

expression(){
  logical();
  while( token==Becomes ){
    get_token();
    logical();
  }
}

prefixed(){
  if( token==Plus || token==Minus 
   || token==Not  || token==Amper ){
    get_token();
    prefixed();
  }else{
    suffixed();
  }
}

equality(){
  comparison();
  while( token==Equ || token==Neq ){
    get_token();
    comparison();
  }
}

const_expr(){
  arithmetic();
}

arith_term(){
  prefixed();
  while( token==Times || token==Divide || token==Remainder ){
    get_token();
    prefixed();
  }
}

logical_term(){
  equality();
  while( token==And ){
    get_token();
    equality();
  }
}

declarator(){
  if( token==Lbracket ){
    get_token();
    const_expr();
    if( token==Rbracket ) get_token(); else error();
  }
}
  
var_decl(){
  declarator();
  while( token==Comma ){
    get_token();
    if( token==Name ) get_token(); else error();
    declarator();
  }
  if( token==Semicolon )  get_token(); else error();
}

enum_declarator(){
  if( token==Name ){
    get_token();
    if( token==Becomes ){
      get_token();
      const_expr();
    }
  }else{
    error();
  }
}

enum_decl(){
  if( token==Enum ){
    get_token();
    if( token==Lbrace )  get_token(); else error();
    enum_declarator();
    while( token==Comma ){
      get_token();
      enum_declarator();
    }
    if( token==Rbrace ) get_token(); else error();
    if( token==Semicolon ) get_token(); else error();
  }else{
    error();
  }
}

int first_expr(int token){
  return (token==Plus || token==Minus || token==Not || token==Amper
       || token==Name || token==Const || token==Character 
       || token==String || token==Lpar );
}

expr_statement(){
  if( first_expr(token) ){
    expression();
    if( token==Semicolon ) get_token(); else error(); 
  }else{
    error();
  }
}

while_statement(){
  if( token==While ){
    get_token();
    if( token==Lpar ) get_token(); else error();
    expression();
    if( token==Rpar ) get_token(); else error();
    statement();
  }else{
    error();
  }
}

int first_stmt(int token){
  return (token==Semicolon || first_expr(token) || token==If
       || token==While || token==Return || token==Lbrace );
}

block(){
  if( token==Lbrace ){
    get_token();
    while( token==Int || token==Enum ){
      if( token==Int ){
        var_decl();
      }else{
        enum_decl();
      }
    }
    while( first_stmt(token) ){
      statement();
    }
    if( token==Rbrace ) get_token(); else error();
  }else{
    error();
  }
}

if_statement(){
  if( token==If ){
    get_token();
    if( token==Lpar ) get_token(); else error();
    expression(); 
    if( token==Rpar ) get_token(); else error();
    statement();
    if( token==Else ){
      get_token();
      statement();
    }
  }else{
    error();
  }
}

return_statement(){
  if( token==Return ){
    get_token();
    if( first_expr(token) ){
      expression(); 
    }
    if( token==Semicolon ) get_token(); else error();
  }else{
    error();
  }
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
    error();
  }
}

enum{ n_param, n_int, n_name };

parameter(int c[]){ int s;
  s= 0;
  if( token==Int  ){ s= 1;  c[n_int]= c[n_int]+1;   get_token(); }
  if( token==Name ){ s= 1;  c[n_name]= c[n_name]+1; get_token(); }
  if( token==Lbracket ){
    if( s==0 ) error();
    get_token();
    if( token==Rbracket ) get_token(); else error();
  }
  c[n_param]= c[n_param]+1;
}

func_decl(){ int c[n_name+1];
  c[n_param]= c[n_int]= c[n_name]= 0;
  if( token==Int ) get_token();
  if( token==Name ){
    get_token();
    if( token==Lpar ) get_token(); else error();
    if( token!=Rpar ){
      parameter(c); 
      while( token==Comma ){
        get_token();
        parameter(c); 
      }
    }
    if( token==Rpar ) get_token(); else error();
    if( token==Semicolon ){
      if( c[n_param]!=c[n_int] ) error();
      get_token();
    }else
    if( token==Lbrace ){
      if( c[n_param]!=c[n_name] ) error();
      block();
    }else{
      error();
    }
  }else{
    error();
  }
}

int first_decl(int token){
  return (token==Int || token==Enum || token==Name );
}

declaration(){
  if( token==Int ){
    get_token();
    if( token==Name ) get_token(); else error();
    if( token==Lpar ){
      func_decl_p();
    }else{
      var_decl_p();
    }
  }else
  if( token==Name ){
    func_decl();
  }else
  if( token==Enum ){
    enum_decl();
  }else{
    error();
  }
}

program(){
  while( first_decl(token) ){
    declaration();
  }
}


