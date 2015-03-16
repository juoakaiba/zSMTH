//
//  LoginViewController.m
//  zSMTH
//
//  Created by Zhengfa DANG on 2015-3-11.
//  Copyright (c) 2015 Zhengfa. All rights reserved.
//

#import "LoginViewController.h"
#import "SMTHHelper.h"
#import "ZSMTHSetting.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.editUsername setText:setting.username];
    [self.editPassword setText:setting.password];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    // show network connection status
//    SMTHHelper *helper = [SMTHHelper sharedManager];
    [helper updateNetworkStatus];
    if(helper.nNetworkStatus == -1){
        [self.netStatus setText:@"没有网络连接"];
    } else if(helper.nNetworkStatus == 0){
        [self.netStatus setText:@"连接到WIFI"];
    } else if(helper.nNetworkStatus == 1){
        [self.netStatus setText:@"连接到移动网络"];
    }
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

- (IBAction)login:(id)sender {
    
    [self startAsyncTask];

}

- (void)asyncTask
{
    setting.username = [self.editUsername text];
    setting.password = [self.editPassword text];
    
    int status = [helper login:[self.editUsername text] password:[self.editPassword text]];
    NSLog(@"Login result: %d", status);
}



- (IBAction)cancel:(id)sender {
}
- (IBAction)showLeftMenu:(id)sender {
    [self.view endEditing:YES];
    [self.frostedViewController.view endEditing:YES];
    
    // Present the view controller
    //
    [self.frostedViewController presentMenuViewController];
}
@end