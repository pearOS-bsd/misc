/* launchd for the session of wsbsd: starts the jobs of the launch agent property lists (as macOS's launchd starts the Dock, SystemUIServer and Finder from /System/Library/LaunchAgents) and keeps them running.
 * Understood keys: Label, Program, ProgramArguments, RunAtLoad, KeepAlive (YES, NO, or { SuccessfulExit = NO } to restart after a failure only), Disabled, EnvironmentVariables, WorkingDirectory, StandardOutPath, StandardErrorPath, ThrottleInterval (default 10 s: a job that runs shorter than this waits for the rest of it before it is started again).
 * Usage: launchd [directory ...] (default /System/Library/LaunchAgents /Library/LaunchAgents ~/Library/LaunchAgents). SIGTERM stops the jobs and ends. Everything else of launchd (sockets, calendar intervals, launchctl) is not implemented. */
#import <Foundation/Foundation.h>
#include <spawn.h>
#include <signal.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>

extern char **environ;
static volatile sig_atomic_t gStop;
static void onTerm(int s) { gStop = 1; }

@interface Job : NSObject { @public NSString *label; NSArray *args; NSDictionary *plist; pid_t pid; NSDate *started, *nextStart; BOOL keepAlive, onlyFailure, enabled; double throttle; }
@end
@implementation Job @end

static BOOL Truthy(id v) { return [v respondsToSelector: @selector(boolValue)] && [v boolValue]; }

static NSMutableArray *LoadJobs(NSArray *dirs)
{
	NSMutableArray *jobs = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *dir in dirs) for (NSString *f in [[fm contentsOfDirectoryAtPath: dir error: NULL] sortedArrayUsingSelector: @selector(compare:)]) {
		if (![f hasSuffix: @".plist"]) continue; NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile: [dir stringByAppendingPathComponent: f]]; if (![p isKindOfClass: [NSDictionary class]] || !p[@"Label"]) continue;
		NSArray *a = p[@"ProgramArguments"]; if (![a count] && p[@"Program"]) a = @[ p[@"Program"] ]; if (![a count] || Truthy(p[@"Disabled"])) continue;
		Job *j = [[Job alloc] init]; j->label = p[@"Label"]; j->args = a; j->plist = p; id ka = p[@"KeepAlive"]; j->keepAlive = [ka isKindOfClass: [NSDictionary class]] ? YES : Truthy(ka); j->onlyFailure = [ka isKindOfClass: [NSDictionary class]] && ka[@"SuccessfulExit"] && !Truthy(ka[@"SuccessfulExit"]);
		j->throttle = p[@"ThrottleInterval"] ? [p[@"ThrottleInterval"] doubleValue] : 10; j->enabled = Truthy(p[@"RunAtLoad"]) || j->keepAlive; [jobs addObject: j];
	}
	return jobs;
}
static void Start(Job *j)
{
	NSMutableArray *env = [NSMutableArray array]; for (char **e = environ; *e; e++) [env addObject: @(*e)];
	NSDictionary *ev = j->plist[@"EnvironmentVariables"]; for (NSString *k in ev) { NSString *pre = [k stringByAppendingString: @"="]; for (NSUInteger i = 0; i < [env count]; i++) if ([env[i] hasPrefix: pre]) { [env removeObjectAtIndex: i]; break; } [env addObject: [pre stringByAppendingString: [ev[k] description]]]; }
	char **argv = calloc([j->args count] + 1, sizeof(char *)), **envp = calloc([env count] + 1, sizeof(char *)); for (NSUInteger i = 0; i < [j->args count]; i++) argv[i] = strdup([j->args[i] UTF8String]); for (NSUInteger i = 0; i < [env count]; i++) envp[i] = strdup([env[i] UTF8String]);
	posix_spawn_file_actions_t fa; posix_spawn_file_actions_init(&fa);
	NSString *out = j->plist[@"StandardOutPath"], *err = j->plist[@"StandardErrorPath"] ?: out;
	if (out) posix_spawn_file_actions_addopen(&fa, 1, [out UTF8String], O_WRONLY | O_CREAT | O_APPEND, 0644); if (err) posix_spawn_file_actions_addopen(&fa, 2, [err UTF8String], O_WRONLY | O_CREAT | O_APPEND, 0644);
	NSString *wd = j->plist[@"WorkingDirectory"]; if (wd) { char cwd[1024]; getcwd(cwd, sizeof cwd); chdir([wd UTF8String]); }
	pid_t pid = 0; int r = posix_spawn(&pid, argv[0], &fa, NULL, argv, envp); if (wd) chdir("/");
	if (r == 0) { j->pid = pid; j->started = [NSDate date]; NSLog(@"launchd: started %@ (pid %d)", j->label, (int)pid); } else { j->pid = 0; j->nextStart = [NSDate dateWithTimeIntervalSinceNow: j->throttle]; NSLog(@"launchd: cannot start %@: %s", j->label, strerror(r)); }
	posix_spawn_file_actions_destroy(&fa); for (char **p = argv; *p; p++) free(*p); for (char **p = envp; *p; p++) free(*p); free(argv); free(envp);
}

int main(int argc, char **argv)
{
	@autoreleasepool {
		signal(SIGTERM, onTerm); signal(SIGINT, onTerm); signal(SIGPIPE, SIG_IGN);
		NSMutableArray *dirs = [NSMutableArray array]; for (int i = 1; i < argc; i++) [dirs addObject: @(argv[i])];
		if (![dirs count]) dirs = [@[ @"/System/Library/LaunchAgents", @"/Library/LaunchAgents", [NSHomeDirectory() stringByAppendingPathComponent: @"Library/LaunchAgents"] ] mutableCopy];
		NSArray *jobs = LoadJobs(dirs); NSLog(@"launchd: %lu jobs from %@", (unsigned long)[jobs count], dirs);
		for (Job *j in jobs) if (j->enabled) Start(j);
		while (!gStop) {
			int st; pid_t w; while ((w = waitpid(-1, &st, WNOHANG)) > 0) for (Job *j in jobs) if (j->pid == w) {
				BOOL ok = WIFEXITED(st) && WEXITSTATUS(st) == 0; double ran = -[j->started timeIntervalSinceNow]; j->pid = 0;
				NSLog(@"launchd: %@ exited (%@ %d) after %.1f s", j->label, WIFSIGNALED(st) ? @"signal" : @"status", WIFSIGNALED(st) ? WTERMSIG(st) : WEXITSTATUS(st), ran);
				if (j->keepAlive && !(j->onlyFailure && ok)) j->nextStart = [NSDate dateWithTimeIntervalSinceNow: MAX(0, j->throttle - ran)];
			}
			for (Job *j in jobs) if (!j->pid && j->nextStart && [j->nextStart timeIntervalSinceNow] <= 0) { j->nextStart = nil; Start(j); }
			usleep(300000);
		}
		for (Job *j in jobs) if (j->pid) kill(j->pid, SIGTERM); sleep(1); for (Job *j in jobs) if (j->pid) kill(j->pid, SIGKILL);
	}
	return 0;
}
