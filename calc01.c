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
int arithmetic();

typedef struct{		//変数用の構造体
	int value;
	char name;
	int isDeclared;
}
