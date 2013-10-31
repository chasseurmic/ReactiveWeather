//
//  TWRViewController.m
//  ReactiveCocoa
//
//  Created by Michelangelo Chasseur on 26/10/13.
//  Copyright (c) 2013 Touchware. All rights reserved.
//

#import "TWRViewController.h"

@interface TWRViewController ()

// UI
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UIImageView *weatherIconImageView;
@property (weak, nonatomic) IBOutlet UILabel *tempLabel;
@property (weak, nonatomic) IBOutlet UILabel *pressLabel;

// Incoming API data
@property (copy, nonatomic) __block NSString *weatherIconName;
@property (copy, nonatomic) __block NSString *cityName;
@property (copy, nonatomic) __block NSNumber *temperature;
@property (copy, nonatomic) __block NSNumber *pressure;

// Signals
@property (strong, nonatomic) RACSignal *apiSignal;
@property (strong, nonatomic) RACSignal *textSignal;

@end

@implementation TWRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Weather Forecast";
    
    [self setupUIBindings];
    [self setupWeatherButton];
}

- (void)setupUIBindings {
    // Binding cityName ivar to the signal coming from text field input changes
    RAC(self, cityName) = [self textSignal];
    
    // Image view binding
    [RACObserve(self, weatherIconName) subscribeNext:^(NSString *cityName) {
        NSLog(@"Loading image for: %@", cityName);
        [_weatherIconImageView setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:ICON_URL_ENDPOINT, cityName]]];
    }];
    
    // Temperature Label binding
    RAC(self.tempLabel, text) = [RACObserve(self, temperature) map:^id(id value) {
        NSString *retString;
        if (value) {
            retString = [NSString stringWithFormat:@"%@ C", value];
        } else {
            retString = @"Temp.";
        }
        return retString;
    }];
    
    // Pressure Label binding
    RAC(self.pressLabel, text) = [RACObserve(self, pressure) map:^id(id value) {
        NSString *retString;
        if (value) {
            retString = [NSString stringWithFormat:@"%@ mb", value];
        } else {
            retString = @"Press.";
        }
        return retString;
    }];
}

- (void)setupWeatherButton {
     @weakify(self);
    
    // Forecast button will be enabled only if there's at least one character in the text field
    // Signal is passed to the rac_command of the UIButton as its initial state
    RACSignal *enableButtonSignal = [[self textSignal] map:^id(NSString *string) {
        return @(string.length > 0);
    }];
    
    // Command executed by the button when pressed
    _button.rac_command = [[RACCommand alloc] initWithEnabled:enableButtonSignal signalBlock:^RACSignal *(id input) {
        @strongify(self);
        NSLog(@"Button pressed!");
        return [[self apiSignal] map:^id(NSDictionary *JSON) {
            // Setting local ivars from JSON object
            self.weatherIconName = JSON[@"current_observation"][@"icon"];
            self.pressure = JSON[@"current_observation"][@"pressure_mb"];
            self.temperature = JSON[@"current_observation"][@"temp_c"];
            NSLog(@"%@", self.weatherIconName);
            return nil;
        }];
    }];
}

- (RACSignal *)textSignal {
    return [_textField.rac_textSignal map:^id(id value) {
        NSString *urlSafeCityName = [value stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        NSLog(@"%@", urlSafeCityName);
        return urlSafeCityName;
    }];
}

- (RACReplaySubject *)apiSignal {
    // Building the HTTP request
    RACReplaySubject *subject = [RACReplaySubject subject];
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:WEATHER_API_ENDPOINT, _cityName]];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc]
                                         initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"%@", responseObject);
        [subject sendNext:responseObject];
        [subject sendCompleted];
    } failure:nil];
    [operation start];
    
    return subject;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
