#import "Common.h"

@implementation Common


+ (id)objectWithJsonData:(NSData*)data
{
    NSError*    error = nil;
    id          object;
    
    object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error == nil)
    {
        return object;
    }
    else
    {
        NSLog(@"Error de-serializing to JSON data: %@.", [error localizedDescription]);
        
        return nil;
    }
}


+ (NSData*)jsonDataWithObject:(id)object
{
    NSError*    error = nil;
    NSData*     data;
    
    data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    
    if (error == nil)
    {
        return data;
    }
    else
    {
        NSLog(@"Error serializing to JSON data: %@.", [error localizedDescription]);
        
        return nil;
    }
}


+ (id)objectWithFile:(NSString*)fileName
{
    NSString*   path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    NSData*     data = [NSData dataWithContentsOfFile:path];
    
    return [Common objectWithJsonData:data];
}

@end
