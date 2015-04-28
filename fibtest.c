#include<stdio.h>
int main(){
	 int a, b, w, i;
	 a = 0;
	 b = 1;

	 for(i=0;i<100;i++){
			w = a + b;
			a = b;
			b = w;
			printf("%d\n",w);
	 }

	 return 0;
}
