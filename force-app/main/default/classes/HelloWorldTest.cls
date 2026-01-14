@isTest
private class HelloWorldTest {
    @isTest
    static void testSayHello() {
        System.assertEquals('Hello, World!', HelloWorld.sayHello(null));
        System.assertEquals('Hello, Test!', HelloWorld.sayHello('Test'));
    }
}
