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
