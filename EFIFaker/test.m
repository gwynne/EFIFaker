#import <Foundation/Foundation.h>

void __attribute__((noinline)) f(int a, int b, int c, int d, int e, int f, int g)
{
	printf("%d, %d, %d, %d, %d, %d, %d", a, b, c, d, e, f, g);
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		f(1, 2, 3, 4, 5, 6, 7);
	}
}

