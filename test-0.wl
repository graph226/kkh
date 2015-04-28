/* Example Program in WL */

/* 2^n  n=0,1,...,30 */

positive(int);

main(){
  int v, n;
  
  v= 1;  n= 0;
  while( n <= 30 ){
    positive(v);  put('\n');
    v= v*2;
    n= n+1;
  }
}

positive(int n){
  if( n >= 10 )  positive( n/10 );
  put( n%10 + 0x30 );
}
