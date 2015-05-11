#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#define MAX_LINE_LENGTH 64
#define MAX_NAME_LENGTH 16
#define MAX_DATA_LENGTH 128

char ch; //読み込まれた文字
int token = 0; //読み込まれた字句
int value = 0; //読み込まれた整数または変数名の値（整数が読み込まれたときにvalueを見ればその値が分かる）
char buf[MAX_LINE_LENGTH]; //入力文字列
int buf_count; //何文字目まで読みこんだかのカウンタ
typedef struct {
	int value;
	int isDeclared;
} variable;
int variable_name; //変数名を一時的に保存するのに用いる
variable variables[52];
enum {
	Number,
	Name,
	Var,
	Plus, // +
	Minus, // -
	Time, // *
	Devide, // /
	Mod, // %
	Exp, // ^
	Become, // =
	Semicolon, // ;
	Lpar, // (
	Rpar, // )
	Space, // " "
	EndInput, // 終了
	NonToken,
	EndFile,
};

/**************************************************
					字句解析
**************************************************/
int c_type[255];
void init_ctype() {
	int c = 0;
	for (c=0; c<255; ++c) { c_type[c] = NonToken; };
	for (c='0'; c<='9'; ++c) { c_type[c] = Number; };
	for (c='a'; c<='z'; ++c) { c_type[c] = Name; };
	for (c='A'; c<='Z'; ++c) { c_type[c] = Name; };
	c_type['$'] = Var;
	c_type['='] = Become;
	c_type['+'] = Plus;
	c_type['-'] = Minus;
	c_type['*'] = Time;
	c_type['/'] = Devide;
	c_type['%'] = Mod;
	c_type['^'] = Exp;
	c_type[';'] = Semicolon;
	c_type['('] = Lpar;
	c_type[')'] = Rpar;
	c_type[' '] = Space;
	c_type['\n'] = Space;
	c_type['\r'] = Space;
	c_type['\t'] = Space;
	c_type['\v'] = Space;
	c_type['\f'] = Space;
	c_type['\0'] = EndInput;
	c_type[26] = EndFile;
	c_type[4] = EndFile;
}

void get_char() { //一文字読み捨てる関数
	ch = buf[buf_count++];
}

void get_name() { //変数名または関数名を読み捨てる関数（現時点では変数名は1文字）
	value = ch;
	get_char();
} 

void get_number() { //1桁以上の整数を読み捨てる関数
	value = (int)ch-'0';
	get_char();
	while(c_type[ch]==Number) {
		value = (int)value*10 + (ch-'0');
		get_char();
	}
}
void get_token() { //一字句読み捨てる関数
	while(c_type[ch]==Space) { get_char(); } //スペースはそのまま読み捨てる
	if(c_type[ch]==Number){ //整数の場合
		token = Number;
		get_number();
	} else if (c_type[ch]==Name) { //変数名または関数名の場合
		token = Name;
		get_name();
	} else if (c_type[ch]==Var) {
		token = Var;
		get_char();
	} else{//その他の場合
		token = c_type[ch];
		get_char();
	}

}
/**************************************************
				ここまで字句解析
**************************************************/






/**************************************************
					構文解析
**************************************************/


int getVariableIndex(int v) {
	return ('a'<=v && v<='z') ? (v-'a') : ('z'-'a'+1+v-'A');
}
void check_variables(int num) {
	printf("%d : check\n", num);
	for (int i = 0; i < 52; ++i)
	{
		printf("value : %d\n", variables[i].value);
		printf("isDeclared: %d\n", variables[i].isDeclared);

	}
}

int expression();
int substitution();
int arithmetic();
int arith_term();
int prefixed();
int primary();

/***** 式 = 代入式 | 算術式 *****/
int expression() 
{

	int ans;
	if(token == Var) {
		get_token();
		ans = substitution();
	} else {
		ans = arithmetic();
	}
	return ans;
}

/***** 代入式 = (変数宣言子 名前 '=' 算術式) *****/
int substitution() {

	int v;
	if(token == Name) { //変数宣言子は既に読み捨てされている
		variable_name = value; //変数名を保存しておく
		get_token();
		if (token == Become) {
			get_token();
			v = arithmetic();
			//printf("variable_name is %c\n", variable_name);
			variables[getVariableIndex(variable_name)].value = v;
			variables[getVariableIndex(variable_name)].isDeclared = 1;
		} else {
			printf("代入式エラー1\n");
		}
	} else { 
		printf("代入式エラー2\n");
	}

	return v;
}

/***** 算術式 = 算術項 { 加減演算子 算術項 } *****/
int arithmetic() {

	int v = arith_term();
	while (token == Plus || token == Minus) {
		if(token == Plus) {
			get_token();
			v += arith_term();
		} else { // Minus
			get_token();
			v -= arith_term();
		}
	}
	return v;
}

/***** 算術項 = 前置式 { 乗除演算子 前置式 } *****/
int arith_term() {
	int v = prefixed();
	while(token == Time || token == Devide || token == Mod || token == Exp) {
		if (token == Time) {
			get_token();
			v *= prefixed();
		} 
		else if (token == Devide) {
			get_token();
			int tmp = prefixed();
			if(tmp == 0) {
				printf("devided by zero.");
			} else {
				v/=tmp;
			}
		} 
		else if (token == Mod) {
			get_token();
			int tmp = prefixed();
			if(tmp == 0) {
				printf("devided by zero.");
			} else {
				v%=tmp;
			}
		} 
		else { // Exp
			get_token();
			v = (int)pow(v,prefixed());
		}
	}
	return v;
	

}

/***** 前置式 = [ 加減演算子 ] 一次子 *****/
int prefixed() {

	int v = 0;
	if(token == Plus || token == Minus) {
		if(token == Plus) {
			get_token();
			v = primary();
		} else {
			get_token();
			v = -1 * primary();
		}
	} else {
		v = primary();
	}
	return v;
}

/***** 一次子 = ( 名前 | 整数定数| '(' 算術式 ')' )  *****/
/***** 一次子 = ( 整数定数| '(' 算術式 ')' )  *****/

int primary() {

	int v = 0;
	if(token == Name) { //変数名の場合、定義済みなら値を返し、未定義ならエラー
		int index = getVariableIndex(value);
		//printf("value is : %c\n", value);
		//printf("index is : %d\n",index);
		//printf("valiables[index].isDeclared is %d\n", variables[index].isDeclared);
		if(variables[index].isDeclared==1) {
			v = variables[index].value;
		} else {
			printf("変数が未定義です。\n");
		}
		get_token();
	} else if(token == Number) {
		v = value;
		get_token();
	} else if(token == Lpar) {
		get_token();
		v = expression();
		if(token == Rpar) {
			get_token();
		} else {
			printf("Error\n");
		}
	} else {
		printf("Error\n");
	}
	return v;
}


/**************************************************
					ここまで構文解析
**************************************************/

void init() {
	init_ctype();
	printf("> ");
	buf_count = 0;

	if( fgets(buf,sizeof(buf),stdin) == NULL) {
		token=EndFile;
	} else {
		get_char();
		get_token();
	}


}


void init_variables(){
	variable tmp = {0,0};
	for (int i = 0; i < 52; ++i) {
		variables[i] = tmp;
	}
}
//コメント：変数の宣言はできるが、変数の使用はできない。
//これから追記する

int main(void){
	init_variables();
	init();
	while(token!=EndFile) {
		if(token==EndInput) {
			printf("計算式を入力してください。\n");
		} else {
			printf("%d\n", expression());
			if(token!=EndInput) {
				printf("計算に失敗しました。\n");
			}
		} 	
		init();
	}
	return 0;
}



