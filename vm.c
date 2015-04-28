#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define N_OPCODE 31

enum{ LP, LPA, N_2, CALL,RET, SET, J,   JF,
      NEG, ADD, SUB, MUL, DIV, REM, LES, LEQ,
      GRT, GEQ, EQU, NEQ, NOT, AND, OR,  DER,
      POP, TA,
      LG=0x20, LGA, TG,
      L =0x40, LA,  T
    };
       

char *op_repr[N_OPCODE]
 ={ "!",   "!=",  "%",   "&&", 
    "*",   "+",   "-",   "/", 
    "<",   "<=",  "==",  ">", 
    ">=",  "CAL", "DC",  "DER", 
    "DS",  "J",   "JF",  "L",   
    "LA",  "LGA", "LP",  "LPA", 
    "LV",  "NEG", "POP", "RET", 
    "SET", "TA",  "||" 
  };
int  op_code[N_OPCODE]
 ={ 0x14000000, 0x13000000, 0x0D000000, 0x15000000,
    0x0B000000, 0x09000000, 0x0A000000, 0x0C000000,
    0x0E000000, 0x0F000000, 0x12000000, 0x10000000,
    0x11000000, 0x03000000,          0, 0x17000000, 
            -1, 0x06000000, 0x07000000, 0x40000000, 
    0x41000000, 0x21000000, 0x00000000, 0x01000000, 
    0x80000000, 0x08000000, 0x18000000, 0x04000000, 
    0x05000000, 0x19000000, 0x16000000
  };

#define LIMIT_M  20000  
int *M;
int base[4];
int pc, sp, ul;
#define bp  base[2]
#define ll  base[1]

int offset, entry, result;
     

int loader(FILE *f){
  int p;  
  char line[80], d, op[4];
  int c0, c1, c2, c3; char *s; 
  int loc, a, inst;
  int i, j, r;
  
  offset= -1;  entry= -1;  p= 0;
  while( fgets(line, 80, f)!=NULL ){
    switch( line[0] ){
      case ' ':
        if( p<0 || LIMIT_M<=p ) return -3;
        sscanf(&line[1],"%s %d", op, &a);
        i= 0; j= N_OPCODE;
        while( i<j ){
          inst= (i+j)/2;
          r= strcmp(op, op_repr[inst]);
          if( r==0 )  i= j;
          else
          if( r>0 )  i= inst+1;  else  j= inst;
        }
        if( r!=0 ){ printf("ERR: %s\n",line);  return -2;}
        if( op_code[inst]!=-1 ){
          M[p]= op_code[inst]+a;
        }else{ int c0,c1,c2,c3; char *s;
          sscanf(&line[1],"%s %d%d%d%d", op,
                           &c0, &c1, &c2, &c3);
          s= (char *)&M[p];
          *s++ = c0; *s++ = c1; *s++ = c2; *s++ = c3;
        }
        p= p+1;   break;
      case 'L':
        sscanf(&line[1], "%d", &loc);
        p= loc;  break;
      case 'F':
        sscanf(&line[1], "%d %d", &loc, &a);
        M[loc]= M[loc]+a;
        break;
      case 'S':
        sscanf(&line[1], "%d", &loc);
        offset= loc;   break;
      case 'E':
        sscanf(&line[1], "%d", &loc);
        entry= loc;   break;
      default:
        return -1;
    }
  }
  if( offset>=0 && entry>=0 )  return p;
  return -4;
}


FILE *fp[8];

int find_fp(){ int i;
  i= 4;
  while( i!=8 && fp[i]!=NULL ) i= i+1;
  if( i==8 ) i= 0;
  return i;
}

int executer(FILE *in, FILE *out, FILE *err){
  int w, i, a;
  int mask[2]= { 0x00000000, 0xFFFFFFFF };
  
  fp[0]= NULL; fp[1]= in;  fp[2]= out;  fp[3]= err;
  {int i; for(i= 4;i!=8;i= i+1) fp[i]= NULL;}
  
  bp= 0;  sp= ll+offset; base[0]= 0;
  M[sp]= bp;  M[sp+1]= ll;  bp= sp;  sp= sp+2;
  while( pc < ll ){ 
    w= M[pc];  pc= pc+1;
    if( w < 0 ){/* LV */
      M[sp]= w & 0x7FFFFFFF;  sp= sp+1;
    }else{ 
      i= w>>24;
      a= (w & 0x00FFFFFF) + base[w>>29];
      switch( i ){
        case L: case LP:
          M[sp]= M[a];  sp= sp+1;  break;
        case LPA: case LA: case LGA:
          M[sp]= a;  sp= sp+1;  break;
        case CALL:
          switch( M[sp-a-1] ){
            case 0:/* exit(int) */
              pc= ll;  break;
            case 1:/* int get() */
              { int r;
                r= fgetc(fp[1]);
                if( r==EOF )  r= -1;
                M[sp-1]= r;
              }  break;
            case 2:/* int put(int) */
              sp= sp-1; 
              { int r; 
                r= fputc(M[sp],fp[2]);
                if( r==EOF) r= -1;
                M[sp-1]= r;
              }  break;
            case 3:/* int err(int) */
              sp= sp-1;
              { int r; 
                r= fputc(M[sp],fp[3]);
                if( r==EOF) r= -1;
                M[sp-1]= r;
              }  break;
            case 4:/* int fopen(int[],int[]) */
              sp= sp-2;
              { int i; 
                i= find_fp();
                if( i!=0 )
                  fp[i]= fopen((char *)&M[M[sp]],
                               (char *)&M[M[sp+1]]);
                if( fp[i]==NULL ) i= 0;
                M[sp-1]= i;
              }  break;
            case 5:/* int fclose(int) */
              sp= sp-1;
              { int i, r;   i= M[sp]; r= -1;
                if( 4<=i && i<=7 && fp[i]!=NULL ){
                  r= fclose(fp[i]);  fp[i]= NULL;
                  if( r==EOF ) r= -1;
                }
                M[sp-1]= r;
              }  break;
            case 6:/* int fgetc(int) */
              sp= sp-1;
              { int i, r;  i= M[sp]; r= -1;
                if( 1<=i && i<=7 && fp[i]!=NULL ){ 
                  r= fgetc(fp[i]);
                  if( r==EOF ) r= -1;
                }
                M[sp-1]= r;
              }  break;
            case 7:/* int fputc(int, int) */
              sp= sp-2;
              { int i, r;  i= M[sp+1]; r= -1;
                if( 1<=i && i<=7 && fp[i]!=NULL ){
                  r=fputc(M[sp],fp[i]);
                  if( r==EOF ) r= -1;
                }
                M[sp-1]= r;
              }  break;
            case 8:/* int fgets(int[],int,int) */
              sp= sp-3;
              { int i, r;  i= M[sp+2]; r= 0;
                if( 1<=i && i<=7 && fp[i]!=NULL ){
                  if( ll<=M[sp] )
                  if( fgets((char *)&M[M[sp]],
                             M[sp+1]*4, fp[i])==NULL )
                    r= 0; 
                  else  r= 1;
                }
                M[sp-1]= r;
              }  break;
            case 9:/* int fputs(int[],int) */
              sp= sp-2;
              { int i, r;  i= M[sp+1]; r= -1;
                if( 1<=i && i<=7 && fp[i]!=NULL ){
                  r= fputs((char *)&M[M[sp]],fp[i]);
                  if( r==EOF ) r= -1;
                }
                M[sp-1]= r;
              }  break;
            case 10:/* int pack(int[],int,int[]) */
              sp= sp-3;
              { int c;  c= 0;
                if( ll<=M[sp+2] ){ int *s, u; char *d;
                  s= &M[M[sp]]; 
                  d= (char *)&M[M[sp+2]];
                  u= M[sp+1];
                  while( c<u ){
                    *d++ = *s++; c= c+1;
                  } *d++ = '\0'; c= c+1;
                  while( c%4!=0 ){
                    *d++ = '\0'; c= c+1;
                  }
                }
                M[sp-1]= c/4;
              }  break; 
            case 11:/* int unpack(int[],int[]) */
              sp= sp-2;
              { int c;  c= 0;
                if( ll<=M[sp+1] ){ int *d; char *s;
                  s= (char *)&M[M[sp]];  
                  d= &M[M[sp+1]];
                  while( *s!='\0' ){
                    *d++ = *s++;  c= c+1;
                  }
                }
                M[sp-1]= c;
              }  break;
            case 12: case 13: case 14: case 15:
     printf("unused: %08X\n", w);
              /* unuseM SVC */  return -1;
            default:
              M[sp]= bp;  M[sp+1]= pc;  sp= sp+2;
              bp= sp-a-2;
              pc= M[sp-a-3];
              if( pc>=ll ){ printf("call: %d\n", pc);
                return -2;
              }
          }  break;
        case RET:
          sp= sp-1;
          M[bp-1]= M[sp];
          pc= M[bp+1+a];
          sp= bp;  bp= M[bp+a];
          if( (unsigned)bp >= sp-2 ) return -6;  break;
        case SET:
          sp= bp+a;
          if( sp>=ul ){ printf("stack overflow\n");
            return -2;  
          } break;
        case J:
          pc= a;
          if( pc>=ll ){ printf("undefined J %d\n", pc);
            return -1;  
          }  break;
        case JF:
          sp= sp-1;
          if( !M[sp] ){
            pc= a;
            if( pc>=ll ){ printf("undefined JF %d\n", pc);
              return -1;
            }
          } break;
        case NEG:
          M[sp-1]= -M[sp-1];  break;
        case ADD:
          sp= sp-1;
          M[sp-1]= M[sp-1]+M[sp];  break;
        case SUB:
          sp= sp-1;
          M[sp-1]= M[sp-1]-M[sp];  break;
        case MUL:
          sp= sp-1;
          M[sp-1]= M[sp-1]*M[sp];  break;
        case DIV:
          sp= sp-1;
          M[sp-1]= M[sp-1]/M[sp];  break;
        case REM:
          sp= sp-1;
          M[sp-1]= M[sp-1]%M[sp];  break;
        case LES:
          sp= sp-1;
          M[sp-1]= (M[sp-1]<M[sp]);  break;
        case LEQ:
          sp= sp-1;
          M[sp-1]= (M[sp-1]<=M[sp]);  break;
        case GRT:
          sp= sp-1;
          M[sp-1]= (M[sp-1]>M[sp]);  break;
        case GEQ:
          sp= sp-1;
          M[sp-1]= (M[sp-1]>=M[sp]);  break;
        case EQU:
          sp= sp-1;
          M[sp-1]= (M[sp-1]==M[sp]);  break;
        case NEQ:
          sp= sp-1;
          M[sp-1]= (M[sp-1]!=M[sp]);  break;
        case NOT:
          M[sp-1]= !M[sp-1];  break;
        case AND:
          sp= sp-1;
          M[sp-1]= (M[sp-1]&&M[sp]);  break;
        case OR:
          sp= sp-1;
          M[sp-1]= (M[sp-1]||M[sp]);  break;
        case DER:
          if( (unsigned)M[sp-1] >= sp ) return -4;
          M[sp-1]= M[M[sp-1]];  break;
        case POP:
          sp= sp-1;  break;
        case TA:
          sp= sp-1;
          if( (unsigned)M[sp-1] >= sp ) return -4;
          if( M[sp-1]<ll ) return -4;
          M[M[sp-1]]= M[sp];
          M[sp-1]= M[sp];  break;
        default:
          return -5;
      }
    }
  }
  { int i;
    for(i= 4;i!=8;i= i+1)
      if( fp[i]!=NULL ) fclose(fp[i]);
  }   
  result= M[sp-1]; return 0;
}

FILE *fin, *fout, *ferr;

int char_type[256]=
  { 0,2,2,2,2,2,2,2, 1,1,1,1,1,1,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    1,4,2,4,4,4,2,2, 2,2,4,4,4,4,4,4,
    4,4,4,4,4,4,4,4, 4,4,4,2,3,4,3,4,
    4,4,4,4,4,4,4,4, 4,4,4,4,4,4,4,4,
    4,4,4,4,4,4,4,4, 4,4,4,4,2,4,4,4,
    4,4,4,4,4,4,4,4, 4,4,4,4,4,4,4,4,
    4,4,4,4,4,4,4,4, 4,4,4,4,2,4,4,2,
    
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2
   };

int command(){
  int res;  char line[100],f[100], *p, *q;

  fflush(stdout);fflush(stderr);fflush(stdin);
  printf("%% "); fgets(line,100,stdin); 
  p= line; q= (char *)M;  res= 0;
  while( *p!='\0' && res==0 ){
    while( char_type[*p]==1 ) p++;
    if( *p=='\0' )  break;
    if( char_type[*p]==4 ){
      while( char_type[*p]==4 ) *q++ = *p++;  *q++ = ' ';
    }else
    if( char_type[*p]==3 ){ char *r; int d;
      if( *p=='<' ){
        d= 1;  p++;
      }else{
        d= 2;  p++;
        if( *p=='>' ){ d= d+2; p++; }
        if( *p=='&' ){ d= d+1; p++; }
      }
      while( char_type[*p]==1 )  p++;
      r= f;
      while( char_type[*p]==4 ) *r++ = *p++;  *r++ = '\0';
      if( *f=='\0' ){
        printf("syntax error\n");  res= -1; 
        continue;
      }
      switch( d ){
        case 1:
          if( fin!=stdin )  fclose(fin);
          fin= fopen(f, "r");
          if( fin==NULL ){
            printf("can't open(r): %s\n", f);  res= -1;
          }
          break;
        case 2: case 3:
          if( fout!=stdout )  fclose(fout);
          if( d==3 && ferr!=stderr )  fclose(stderr);
          fout= fopen(f, "w");
          if( fout==NULL ) {
            printf("can't open(w): %s\n", f);  res= -1;
          }
          if( d==3 )  ferr= fout;
          break;
        case 4: case 5:
          if( fout!=stdout )  fclose(fout);
          if( d==5 && ferr!=stderr )  fclose(stderr);
          fout= fopen(f, "a");
          if( fout==NULL ){
            printf("can't open(a): %s\n", f);  res=-1;
          }
          if( d==5 )  ferr= fout;
          break;
      }
    }else{
      printf("syntax error\n");  res= -1;
      continue;
    }
  }
  if( q!=(char *)M ) q--;
  *q= '\0';
  return res;
}

closing(){
  if( fin!=NULL && fin!=stdin )  fclose(fin);
  if( ferr!=NULL && ferr!=stderr ){
    fclose(fout);  fclose(ferr);
  }else
  if( fout!=NULL && fout!=stdout )  fclose(fout);
}

main(){
 
  M= (int *)malloc(LIMIT_M*sizeof(int));
  fin= stdin;  fout= stdout;  ferr= stderr;
  
  while( 1 ){ int res; char com[100]; FILE *f;
    closing();
    fin= stdin;  fout= stdout;  ferr= stderr;
    if( (res= command())==0 ){char *p, *q;
      p= (char *)M;  q= com;
      while( *p!=' ' && *p!='\0' ) *q++ = *p++;  *q= '\0';
      if( *com=='\0' )  continue;
      if( strcmp(com, "exit")==0 ){ 
        closing();  exit(0);
      }
      f= fopen(com,"r");
      if( f==NULL ){ 
        printf("unknown: %s\n", com);
        continue;
      }
      res= loader(f);  fclose(f);
      if( res<0 ){ 
        printf("Loading fails(%d)\n",res);
        continue;
      }
      ll= res;  ul= LIMIT_M;  pc= entry;
      res= executer(fin, fout, ferr);
      if( res<0 ){ 
        printf("Execution fails(%d)\n", res);
        continue;
      }
      if( result!=0 ) printf("\n\nreturn code: %d\n", result);
    }
  }
}
