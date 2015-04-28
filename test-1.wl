/* Example Program in WL */


/* WL provides no direct facility for input/output numbers. */
/* You must write such facility by yourself.                */

put_n(int value, int width, int file){
/* put_n(n,w,f):                                */
/*	output ab integer n in decimal notation	*/
/*	onto a file f;                          */
/*  at least w characters are output.           */
  int v, d[10], i;

  v= value;
  if( value < 0 ){ v= -v; width= width-1; }
  d[0]= v%10; v= v/10;  i= 1;
  while( v > 0 ){
    d[i]= v%10;  v= v/10;  i= i+1;
  }
  while( width > i ){
    fputc(' ', file);  width= width-1;
  }
  if( value < 0 )  fputc('-', file);
  while( i != 0 ){
    fputc(d[i-1]+'0', file);  i= i-1;
  }
}

int get_n(int file){ int c, s, n;
/* get(f):                                    */
/*	input a (possibly signed) number      */
/*	from a file f, and returns its value  */

  n= 0; s= 0;
  while( (c= fgetc(file))!=EOF && c==' ');
  if( c == '-' || c == '+' ){
    if( c == '-' ) s= 1;  
    while( (c= fgetc(file))!=EOF && c==' ');
  }
  while( '0'<=c && c<='9' ){
    n= n*10 + c-'0';  c= fgetc(file);
  }
  if( s )  n= -n;
  return n;
}

/* Given n, prints first n terms of the Fibonacci sequence */
main(){
  int n, i, a, b, w;
  
  fputs("Fibonacci Sequence\n", stdout);
  fputs("How may terms? > ",stdout);  n= get_n(stdin);
  i= 0; a= 0; b= 1; fputc('\n',stdout);
  while( i < n ){
    put_n(i, 3,stdout);  fputc(':', stdout);
    put_n(a,12,stdout);  fputc('\n', stdout);
    w= a+b;  a= b;  b= w;
    i= i+1;
  }
}
    
