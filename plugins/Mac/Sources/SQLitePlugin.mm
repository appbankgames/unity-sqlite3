//
//  Created by Alvin Phu on 12/12/13.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface SQLitePlugin : NSObject
{
	NSString* dbFilename;
    NSString* gameObjectName;
    sqlite3* database;
}

@property (nonatomic, strong) NSString *dbFilename;
@property (nonatomic, strong) NSString *gameObjectName;

- (id)initWithGameObjectName:(const char *)gameObjectName_;
- (bool)openDB:(const char *)dbFilename_;
- (bool)openDB:(const char *)dbFilename_ withDirectory:(NSString*)dbDirectory;
- (void)closeDB;
- (int)executeQuery:(const char *)queryString;
- (bool)executeRowQuery:(const char*)queryString withRows:(const char ***)outRows andNumValues:(int *)outNumValues;
- (const char **)UnityStringArrayFromNSStringArray:(NSArray*)stringArray;

@end

@implementation SQLitePlugin
@synthesize dbFilename;
@synthesize gameObjectName;

- (id)initWithGameObjectName:(const char *)gameObjectName_
{
    self = [super init];
    if (self) {
        self.gameObjectName = (gameObjectName_ == NULL) ? nil : [NSString stringWithUTF8String:gameObjectName_];
        self.dbFilename = nil;
    }
	return self;
}

- (void)dealloc
{
    [self closeDB];
    self.dbFilename = nil;
    self.gameObjectName = nil;
    [super dealloc];
}

- (bool)openDB:(const char *)dbFilename_
{
    return [self openDB: dbFilename_ withDirectory:nil];
}

- (bool)openDB:(const char *)dbFilename_ withDirectory:(NSString*)dbDirectory
{
    self.dbFilename = (dbFilename_ == NULL) ? nil : [NSString stringWithUTF8String:dbFilename_];
    
    // Generate the database path name
    NSString *dbPath = nil;
    
    if (dbDirectory == nil)
    {
        dbPath = [dbDirectory stringByAppendingPathComponent:self.dbFilename];
    }
    else
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES);
        NSString *documentsDir = [paths objectAtIndex:0];
        dbPath = [documentsDir stringByAppendingPathComponent:self.dbFilename];
    }
    
    // Open the SQLite database with the input filename. See if we were able to open it.
    // Keep in mind SQLite WILL create an sql database file if it does not already exist. That's nice.
    bool dbOpenedSuccessfully = false;
    if (dbPath != nil)
    {
        dbOpenedSuccessfully = (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK);
        
        // If we were not able to open the database successfully, for whatever reason, we still need to release it from memory
        // using the sqlite call.
        if (!dbOpenedSuccessfully)
        {
            // We still have to close the database to release all the memory.
            [self closeDB];
        }
    }
    
    return dbOpenedSuccessfully;
}

- (void)closeDB
{
    // We still have to close the database to release all the memory.
    if (database != NULL)
    {
        sqlite3_close(database);
        database = NULL;
    }
}

- (int)executeQuery:(const char*)queryString
{
    int queryResult = -1;
    if (database != NULL)
    {
        char *sqlErrorMessage = 0;
        queryResult = sqlite3_exec(database, queryString, nil, nil, &sqlErrorMessage);
        if (queryResult != SQLITE_OK)
        {
            NSLog(@"%@", [NSString stringWithUTF8String:sqlErrorMessage]);
        }
    }
    // Anything not a 0 is unsuccessful.
    
    return queryResult;
}

// Execute a single query and return specifed rows.
- (bool)executeRowQuery:(const char*)queryString withRows:(const char ***)outRows andNumValues:(int *)outNumValues
{  
    sqlite3_stmt *selectstmt;
    int result = -1;
    if (database != NULL) {
        result = sqlite3_prepare_v2(database, queryString, -1, &selectstmt, nil);
    }
    
    if(result == SQLITE_OK)
    {
        NSMutableArray *resultArray = [[NSMutableArray alloc] init];
        bool foundRows = false;
        int numColumns = sqlite3_column_count(selectstmt);
        
        result = sqlite3_step(selectstmt);
        int foundValues = 0;
        
        while (result == SQLITE_ROW)
        {
            foundRows = true;
            NSMutableString* rowString = [NSMutableString stringWithString:[NSString stringWithUTF8String:(char *)sqlite3_column_text(selectstmt, 0)]];
            
            for (int columnIndex = 1; columnIndex < numColumns; columnIndex++)
            {
                [rowString appendString: [NSString stringWithUTF8String: "|"]];
                [rowString appendString: [NSString stringWithUTF8String:(char *)sqlite3_column_text(selectstmt, columnIndex)]];
            }
            
            [resultArray addObject:rowString];
            result = sqlite3_step(selectstmt);
            foundValues++;
        }
        
        // Initialize the row results to the heap and send the pointer address to Unity.
        *outRows = [self UnityStringArrayFromNSStringArray: resultArray];
        *outNumValues = foundValues;
        [resultArray release];
        
        return foundRows;
    }
    
    return false;
}

// Function to pass back a const char * array from an NSString. Required before passing back values to Unity.
- (const char **) UnityStringArrayFromNSStringArray:(NSArray *)stringArray
{
    int stringIndex = 0;
    char ** unityStringArray = (char **)(calloc([stringArray count], sizeof(char *)));
    
    for (NSString* objcString in stringArray)
    {
        char *unityString = strdup([objcString UTF8String]);
        unityStringArray[stringIndex] = unityString;
        ++stringIndex;
    }
    
    const char **retval = (const char **)unityStringArray;
    return retval;
}

@end

extern "C" {
	void *_SQLitePlugin_Init(const char *gameObjectName);
	void _SQLitePlugin_Destroy(void *instance);
	bool _SQLitePlugin_OpenDB(void *instance, const char* dbFilename);
    bool _SQLitePlugin_OpenDBWithDirectory(void *instance, const char* dbFilename, const char* dbDirectory);
    void _SQLitePlugin_CloseDB(void *instance);
    int _SQLitePlugin_ExecuteQuery(void *instance, const char *queryString);
    bool _SQLitePlugin_ExecuteRowQuery(void *instance, const char *queryString, const char ***outRows, int *outNumValues);
}

void *_SQLitePlugin_Init(const char *gameObjectName)
{
	id instance = [[SQLitePlugin alloc] initWithGameObjectName:gameObjectName];
	return (void *)instance;
}

void _SQLitePlugin_Destroy(void* instance)
{
	SQLitePlugin* sqlitePlugin = (SQLitePlugin *)instance;
	[sqlitePlugin release];
}

bool _SQLitePlugin_OpenDB(void *instance, const char *dbFilename)
{
	SQLitePlugin *sqlitePlugin = (SQLitePlugin *)instance;
	return [sqlitePlugin openDB:dbFilename];
}

bool _SQLitePlugin_OpenDBWithDirectory(void *instance, const char *dbFilename, const char* dbDirectory)
{
	SQLitePlugin *sqlitePlugin = (SQLitePlugin *)instance;
	return [sqlitePlugin openDB:dbFilename withDirectory:[NSString stringWithUTF8String:dbDirectory]];
}

void _SQLitePlugin_CloseDB(void *instance)
{
	SQLitePlugin *sqlitePlugin = (SQLitePlugin *)instance;
	[sqlitePlugin closeDB];
}

int _SQLitePlugin_ExecuteQuery(void *instance, const char *queryString)
{
	SQLitePlugin *sqlitePlugin = (SQLitePlugin *)instance;
	return [sqlitePlugin executeQuery:queryString];
}

bool _SQLitePlugin_ExecuteRowQuery(void *instance, const char *queryString, const char ***outRows, int *outNumValues)
{
	SQLitePlugin *sqlitePlugin = (SQLitePlugin *)instance;
	return [sqlitePlugin executeRowQuery:queryString withRows:outRows andNumValues:outNumValues];
}
