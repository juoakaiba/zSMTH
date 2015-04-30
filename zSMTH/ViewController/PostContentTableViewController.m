//
//  PostContentTableViewController.m
//  zSMTH
//
//  Created by Zhengfa DANG on 2015-3-22.
//  Copyright (c) 2015 Zhengfa. All rights reserved.
//

#import "PostContentTableViewController.h"
#import "SVPullToRefresh.h"
#import "PostContentTableViewCell.h"
#import "SMTHPost.h"
#import "UIView+Toast.h"
#import "RNGridMenu.h"
#import "PostListTableViewController.h"
#import "TapImageView.h"
#import "MWPhotoBrowser.h"
#import "SMTHAttachment.h"
#import "ContentEditViewController.h"

#define LABEL_WIDTH 300

@interface PostContentTableViewController () <TapImageViewDelegate, MWPhotoBrowserDelegate>
{
    NSMutableArray *mPosts;
    NSMutableDictionary *mHeights;
    int mPageIndex;
    CGFloat iHeaderHeight;
    NSMutableArray *mPhotos;
    
    NSString *chsName;
    NSString *engName;
    long boardID;
}

@end

@implementation PostContentTableViewController

@synthesize postID;
@synthesize postSubject;

- (void)viewDidLoad {
    [super viewDidLoad];

    // load first page
    mPosts = [[NSMutableArray alloc] init];
    mHeights = [[NSMutableDictionary alloc] init];
    iHeaderHeight  = 22.0;
    if(chsName){
        self.title = [NSString stringWithFormat:@"%@(%@)",chsName, engName];
    } else {
        self.title = engName;
    }

    // hide right button if this view is not initiated from Guidance
    if(! self.isFromGuidance){
        [self.navigationItem setRightBarButtonItem:nil];
    }

    // tableview setting
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.allowsSelection = NO;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin| UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight;

    // add pull to refresh function at the top & bottom
    __weak typeof(self) weakSelf = self;
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf refreshPostContent];
    }];
    
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        [weakSelf loadMorePostList];
    }];

    // change translucent, otherwise, tableview will be partially hidden
    self.navigationController.navigationBar.translucent = NO;
    
    // loading content now
    self.progressTitle = @"加载中...";
    self.tableView.showsPullToRefresh = NO;
    self.tableView.showsInfiniteScrolling = NO;
    [self startAsyncTask:nil];
}



-(void) setBoardInfo:(long)boardid chsName:(NSString*)chsname engName:(NSString*) engname;
{
    // 从首页导读调用的时候，没有boardid, 没有chsname
    boardID = boardid;
    engName = engname;
    chsName = chsname;
    if(chsName == nil){
        // 从缓存的所有版面列表中获取中文版名和版面的ID
        // 如果之前没有访问过所有版面，那么会返回空值
        helper = [SMTHHelper sharedManager];
        chsName = [helper getChsBoardName:engName];
        boardID = [helper getBoardID:engName];
    }
}

#pragma mark - Loading Tasks

- (void) refreshPostContent {
    __weak typeof(self) weakSelf = self;
    int64_t delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf.tableView.pullToRefreshView stopAnimating];
        
        weakSelf.progressTitle = @"刷新中...";
        weakSelf.tableView.showsPullToRefresh = NO;
        weakSelf.tableView.showsInfiniteScrolling = NO;
        [weakSelf startAsyncTask:nil];
    });
}

- (void) loadMorePostList {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        weakSelf.tableView.showsPullToRefresh = NO;
        
        mPageIndex += 1;
        NSArray *posts = [helper getPostContents:engName postID:postID from:mPageIndex];
        long currentNumber = [mPosts count];
        if (posts != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView.infiniteScrollingView stopAnimating];
                if ([posts count] > 0) {
                    NSMutableArray *array = [[NSMutableArray alloc] init];
                    for (int i = 0; i < [posts count]; i++) {
                        [array addObject:[NSIndexPath indexPathForRow:currentNumber+i inSection:0]];
                    }

                    [weakSelf.tableView beginUpdates];
                    [mPosts addObjectsFromArray:posts];
                    [weakSelf.tableView insertRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationTop];
                    [weakSelf.tableView endUpdates];
                } else {
                    [weakSelf.tableView.infiniteScrollingView  makeToast:@"没有更多的回复了..."
                                duration:0.5
                                position:CSToastPositionCenter];
                }
                // 重新打开下拉刷新
                weakSelf.tableView.showsPullToRefresh = YES;
            });
        }
    });
}

- (void)asyncTask:(NSMutableDictionary*) params
{
    mPageIndex = 0;
    NSArray *results = [helper getPostContents:engName postID:postID from:mPageIndex];
    [mPosts removeAllObjects];
    [mPosts addObjectsFromArray:results];
}


- (void)finishAsyncTask:(NSDictionary*) resultParams
{
    [self.tableView reloadData];

    self.tableView.showsPullToRefresh = YES;
    self.tableView.showsInfiniteScrolling = YES;
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [mPosts count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return iHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if(section == 0)
    {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 2, tableView.frame.size.width - 10, 36)];
        label.numberOfLines = 2;
        label.text = self.postSubject;
        label.textAlignment = NSTextAlignmentLeft;
        label.font = [UIFont systemFontOfSize:16];
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor clearColor];
        
        CGSize newSize = [label sizeThatFits:label.frame.size];
        CGRect newFrame = CGRectMake(label.frame.origin.x, label.frame.origin.y, label.frame.size.width, newSize.height);
        label.frame = newFrame;

        // update height for header
        iHeaderHeight = newSize.height + 4;
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, iHeaderHeight)];
        view.backgroundColor = [UIColor colorWithRed:230/255.0f green:230/255.0f blue:230/255.0f alpha:0.9f];
        [view addSubview:label];
        
        return view;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 70.0;
    
    id result = [mHeights objectForKey:indexPath];
    if(result != nil)
    {
        height = [((NSNumber*)result) floatValue];
    }
    
//    NSLog(@"%@ height=%f", indexPath, height);
    return height;
}

// http://tewha.net/2015/01/how-to-fix-uitableview-rows-changing-size/
// http://blog.jldagon.me/blog/2013/12/07/auto-layout-and-uitableview-cells/
// 当cell的高度不统一时，这个方法的作用很重要
-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"PostContentTableViewCell";
    
    PostContentTableViewCell *cell = (PostContentTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        NSArray *nibArray = [[NSBundle mainBundle] loadNibNamed:cellIdentifier owner:self options:nil];
        cell = (PostContentTableViewCell*)[nibArray objectAtIndex:0];
        cell.delegate = self;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                              initWithTarget:self action:@selector(handleLongPress:)];
        lpgr.minimumPressDuration = 0.6; //seconds
        [cell addGestureRecognizer:lpgr];
    }
    
    if (indexPath.section == 0) {
        cell.idxPost = indexPath.row;

        SMTHPost *post = (SMTHPost*)[mPosts objectAtIndex:indexPath.row];
        post.postBoard = engName;
        [cell setCellContent:post];
       
        CGFloat height = [cell getCellHeight];
        [mHeights setObject:[NSNumber numberWithFloat:height] forKey:indexPath];
    }
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)return:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - RefreshTableViewProtocol
- (void)RefreshTableView
{
//    [self.tableView setNeedsDisplay];
    [self.tableView reloadData];
}

#pragma mark - Content Actions

- (IBAction)clickRightButton:(id)sender {
    PostListTableViewController *postlist = [self.storyboard instantiateViewControllerWithIdentifier:@"postlistController"];
    postlist.chsName = chsName;  // this field might be null
    postlist.engName = engName;
    [self.navigationController pushViewController:postlist animated:YES];
}

- (void) handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    // only when gesture was recognized, not when ended
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        // get affected cell
        UITableViewCell *cell = (UITableViewCell *)[gesture view];
        // get indexPath of cell
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        // now start our action on long press
//        NSLog(@"Long click on post %ld, %ld", indexPath.section, indexPath.row);
        
        SMTHPost *post = (SMTHPost*)[mPosts objectAtIndex:indexPath.row];
        NSArray *items = @[
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"retweet"]
                                                           title:@"转发到版面"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"0", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"email"]
                                                           title:@"回信给作者"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"1", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"openInBrowser"]
                                                           title:@"浏览器打开"
                                                          action:^{
                                                              if(boardID == 0)
                                                              {
                                                                  [cell makeToast:@"版面ID未知，请先打开一次\"全部讨论区\"!"];
                                                              } else {
                                                                  NSString* url = [NSString stringWithFormat:@"http://www.newsmth.net/bbscon.php?bid=%ld&id=%@", boardID, post.postID];
                                                                  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                                              }
                                                              NSLog(@"%@, %@", @"2", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"forward"]
                                                           title:@"转寄到信箱"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"3", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"reply"]
                                                           title:@"回复"
                                                          action:^{
//                                                              NSLog(@"%@, %@", @"4", post.postID);
                                                              [self replyPost:post];
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"copy"]
                                                           title:@"复制帖子"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"5", post.postID);
                                                              UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                                              [pasteboard setString:post.postContent];
                                                              
                                                              CGRect bounds = [[UIScreen mainScreen] bounds];
                                                              [self.tableView  makeToast:@"帖子内容已复制到剪切板!"
                                                                                duration:0.8
                                                                                position:[NSValue valueWithCGPoint:CGPointMake(bounds.size.width * 0.5, self.tableView.contentOffset.y + bounds.size.height * 0.7)]];

                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"toUser"]
                                                           title:@"转寄给他人"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"6", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"queryUser"]
                                                           title:@"查询作者"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"7", post.postID);
                                                          }],
                           
                           [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"share"]
                                                           title:@"分享"
                                                          action:^{
                                                              NSLog(@"%@, %@", @"8", post.postID);
                                                          }],
                           ];
        RNGridMenu *av = [[RNGridMenu alloc] initWithItems:items];
        av.backgroundColor = [[UIColor alloc] initWithRed:235/255.0 green:1.0 blue:235/255.0 alpha:0.85];
        av.itemTextColor = [UIColor darkTextColor];
        av.itemTextAlignment = NSTextAlignmentCenter;
        av.blurLevel = 0.1;
        av.itemFont = [UIFont boldSystemFontOfSize:15];
        av.itemSize = CGSizeMake(100, 100);
        av.menuStyle = RNGridMenuStyleGrid;
        [av showInViewController:self center:CGPointMake(self.view.bounds.size.width/2.f, self.view.bounds.size.height/2.f)];
    }
}

-(void) replyPost:(SMTHPost*) post
{
    ContentEditViewController *editor = [self.storyboard instantiateViewControllerWithIdentifier:@"contenteditController"];
    
    editor.engName = engName;
    [editor setOrigPostInfo:[post.postID doubleValue] subject:post.postSubject author:post.author content:post.postContent];
    [self.navigationController pushViewController:editor animated:YES];
}

#pragma mark MWPhotoBrowserDelegate
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    if(mPhotos != nil)
        return [mPhotos count];

    return 0;
}


- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    if (index < [mPhotos count])
        return [mPhotos objectAtIndex:index];
    return nil;
}

#pragma mark TapImageViewDelegate

- (void)tappedWithObject:(id)sender
{
    TapImageView *view = (TapImageView*) sender;
    SMTHPost* post = [mPosts objectAtIndex:view.idxPost];
    NSArray* attachs = post.attachments;
    
    // Create array of MWPhoto objects
    if(mPhotos == nil)
        mPhotos = [[NSMutableArray alloc] init];
    else
        [mPhotos removeAllObjects];
    
    
    for(int i=0; i<[attachs count]; i++){
        SMTHAttachment *att = (SMTHAttachment*)[attachs objectAtIndex:i];
        if(![att isImage]){
            // this is not an image
            continue;
        }
        MWPhoto *photo = [MWPhoto photoWithURL:[post getAttachedImageURL:i]];
//        photo.caption = att.attName;
        [mPhotos addObject:photo];
    }
    
    // Create browser (must be done each time photo browser is
    // displayed. Photo browser objects cannot be re-used)
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = NO; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = NO; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = NO; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
//    browser.wantsFullScreenLayout = YES; // iOS 5 & 6 only: Decide if you want the photo browser full screen, i.e. whether the status bar is affected (defaults to YES)
    
    // Optionally set the current visible photo before displaying
    [browser setCurrentPhotoIndex:view.idxImage];
    
    // Present
    [self.navigationController pushViewController:browser animated:YES];
}

@end