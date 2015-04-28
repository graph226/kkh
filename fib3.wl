/*数の出力*/
put_n(int value, int width, int file){

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

/*入力された数の取得*/
int get_n(int file){ int c, s, n;

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

  int n, i, j, k, w, carry, max;
  int a[80],b[80],c[80];
  
  
  fputs("Fibonacci Sequence\n", stdout);
  fputs("How many terms? > ",stdout);  n= get_n(stdin);
  fputc('\n',stdout);
  i= 0;
  
  /* 配列初期化 */
   while(i<80){

   a[i]= 0;
   b[i]= 0;
   c[i]=0;
   i=i+1;
   }
   
   
   b[0]=1;
   i=0;
   
  while( i < n ){
    put_n(i, 3,stdout);  fputc(':', stdout);

  /* 表示 */
   k=0;
   if(i==0) {
   put_n(0,80,stdout);
   }
   if(i>0) {
   while(k<80) {
   if(a[k]>0) max=k;
   k=k+1;
   }
   k=max+1;
   while(k<80){
     fputc(' ', stdout);
     k=k+1;
   }

   j=0;
   while(j<max+1){
   put_n(a[max-j],1,stdout);
   j=j+1;
   }
   }
   fputc('\n',stdout);

  /* 各桁計算 */ 
    j=0;
    carry=0;
    while(j<80){
    w= a[j]+b[j]+carry;
    c[j]=w%10;
    carry=w/10;
     j= j+1;
    }

  /* 配列交換 */
    j=0;
    while(j<80){
    a[j]=b[j];
    b[j]=c[j];
    j=j+1;
    }

    i=i+1;
  }

}
    
