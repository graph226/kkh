#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <limits.h>
#include <setjmp.h>
#include <string.h>

#define STR_LEN 100 //1行の最大文字数
#define M_CHAR 0x80 //charの長さ

void error(char message[]);	//エラーメッセージ用の函数

enum {											//使用する構文様式の宣言
	Times, Divide, Remainder,
	Plus, Minus, Becomes,
	Power,
	Lpar, Rpar,
	Num, Name,
	EndInput, EndFile,
	NonToken,
	SPACE
};

int token;	//次のtoken
int value;
int ch;
int cp;

void get_char();
void get_line();
void get_token();
char str[STR_LEN];
double arithmetic();

typedef struct{		//変数用の構造体
	int value;
	char name;
	int isDeclared;
}

void error(char *message){ //Error表示
	printf("ERROR:: %s\n", message);
	longjmp(env, -1);
}

int str_idx = 0;	//初期位置は0
char ch;					//次のcharを格納
int c_type[M_CHAR];


void init_ctype(){	//字句解析用
	int i;
	i=0; while( i!=M_CHAR ){ c_type[i++]=NonToken; }
	i='a'; while( i<='z' ){ c_type[i++]=Name; }
	i='A'; while( i<='Z' ){ c_type[i++]=Name; }
	i='0'; while( i<='9' ){ c_type[i++]=Num; }
	c_type[' '] = SPACE;	c_type['\n'] = SPACE;
	c_type['\r'] = SPACE;	c_type['\t'] = SPACE;
	c_type['\v'] = SPACE; c_type['\f'] = SPACE;
	c_type['*'] = Times; c_type['/'] = Divide;	c_type['%'] = Remainder;
	c_type['+'] = Plus; c_type['-'] = Minus;	c_type['='] = Becomes;
	c_type['^'] = Power;
	c_type['('] = Lpar; c_type[')'] = Rpar;
	c_type['\0'] = EndInput;
	c_type[26] = EndFile;
	c_type[4] = EndFile;
}

void get_char(){		//1文字先読み
	ch = str[idx++];
}

void get_token(){		//tokenを判定する
	while(c_type[ch] == SPACE) get_char();
	if(c_type[ch] == Num){
		token = Num;
		value = ch-'0';
		get_char();
		while(c_type[ch] == Num){
			if(INT_MAX/10 < value) error("overflow");
			value = value*10 + (ch-'0');
			get_char();
		}
	} else if(c_type[ch] == Name){
		token = Name;
		value = ch;
		get_char();
	} else if(ch == EOF){
		token = EndFile;
		get_char();
	} else {
		token = c_type[ch];
		get_char();
	}
}


void get_input(){		//入力を受け付ける
	printf(">");
	fgets(line, STR_LEN, stdin);
	cp = 0;
}

int checkOverflow(int result){
	if(result > INT_MAX || result < INT_MIN){
		errot("Overflow");
	}
	return result;
}

double primary();			//一次式
double arith_term();	//算術項

