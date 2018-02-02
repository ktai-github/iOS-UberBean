// Copyright (c) 2017 Lighthouse Labs. All rights reserved.
// 
// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
// distribute, sublicense, create a derivative work, and/or sell copies of the
// Software in any work that is designed, intended, or marketed for pedagogical or
// instructional purposes related to programming, coding, application development,
// or information technology.  Permission for such use, copying, modification,
// merger, publication, distribution, sublicensing, creation of derivative works,
// or sale is expressly withheld.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MapViewController.h"
@import MapKit;
@import CoreLocation;
#import "Cafe.h"

@interface MapViewController ()<CLLocationManagerDelegate, MKMapViewDelegate>

@property (nonatomic) MKMapView *mapView;
@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) CLLocation *currentLocation;
@property (nonatomic) NSArray <MKAnnotation>*cafes;

@end

@implementation MapViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self createMapView];
  self.locationManager = [[CLLocationManager alloc] init];
  self.locationManager.delegate = self;
  self.mapView.delegate = self;
  [self.mapView registerClass:[MKMarkerAnnotationView class] forAnnotationViewWithReuseIdentifier:@"Cafe"];
  // request authorization only runs if not determined, but
  [self.locationManager requestWhenInUseAuthorization];
}


#pragma mark - Create Map

- (void)createMapView {
  self.mapView = [[MKMapView alloc] init];
  self.mapView.showsUserLocation = YES;
  [self.view addSubview:self.mapView];
  
  self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.mapView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
  [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
  [self.mapView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
  [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
}

#pragma mark - Networking

-(void)fetchCafesWithUserLocation:(CLLocationCoordinate2D)location searchTerm:(NSString *)searchTerm completion:(void(^)(NSArray<MKAnnotation>*))handler {
  
  NSString *yelpAPIString = @"https://api.yelp.com/v3/businesses/search";
  NSString *yelpAPIKey = @"2_h9hGfTkNbvoEYCYAY-9c2J-aF1w2bvhsOVM-69_-rDecmiQsJs-mhW9HjfmfSk-LSNlri6VXz2klSTJQkrAlogC1xijeZpPhk4TGoan20nwT_vWpH2JRXjnw1YWnYx";
  
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithString:yelpAPIString];
  NSURLQueryItem *categoryItem = [NSURLQueryItem queryItemWithName:@"categories" value:@"cafes"];
  NSURLQueryItem *searchItem = [NSURLQueryItem queryItemWithName:@"term" value:searchTerm];
  NSURLQueryItem *latItem = [NSURLQueryItem queryItemWithName:@"latitude" value:@(location.latitude).stringValue];
  NSURLQueryItem *lngItem = [NSURLQueryItem queryItemWithName:@"longitude" value:@(location.longitude).stringValue];
  urlComponents.queryItems = @[categoryItem, latItem, lngItem,searchItem];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlComponents.URL];
  request.HTTPMethod = @"GET";
  [request addValue:[NSString stringWithFormat:@"Bearer %@", yelpAPIKey] forHTTPHeaderField:@"Authorization"];
  [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    
    if (error) {
      NSLog(@"%@", error.localizedDescription);
      return;
    }
    
    NSUInteger statusCode = ((NSHTTPURLResponse*)response).statusCode;
    
    if (statusCode != 200) {
      NSLog(@"Error: status code is equal to %@", @(statusCode));
      return;
    }
    if (data == nil) {
      NSLog(@"Error: data is nil");
      return;
    }
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    
    NSArray<NSDictionary *>*jsonArray = json[@"businesses"];
    
    NSMutableArray *cafes = [NSMutableArray arrayWithCapacity:jsonArray.count];
    
    for (NSDictionary *item in jsonArray) {
      Cafe *cafe = [[Cafe alloc] initWithJSON:item];
      [cafes addObject:cafe];
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      handler([cafes copy]);
    }];
    
  }];
  
  [task resume];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  if (!self.currentLocation) {
    self.currentLocation = locations.firstObject;
    self.mapView.showsUserLocation = YES;
    [self setupRegion];
    
    [self fetchCafesWithUserLocation:self.currentLocation.coordinate searchTerm:nil completion:^(NSArray<MKAnnotation> *cafes) {
      self.cafes = cafes;
    }];
  }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
  if ([annotation isKindOfClass:[MKUserLocation class]]) {
    return nil;
  }
  MKMarkerAnnotationView *annotationView = (MKMarkerAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"Cafe" forAnnotation:annotation];
  if (annotationView == nil) {
    annotationView = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Cafe"];
  } else {
    annotationView.annotation = annotation;
  }
  
  annotationView.canShowCallout = YES;
  annotationView.animatesWhenAdded = YES;
  annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeInfoLight];
  return annotationView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
  
}

static const double lat = 0.01;
static const double lng = 0.01;

- (void)setupRegion {
  MKCoordinateSpan span = MKCoordinateSpanMake(lat, lng);
  MKCoordinateRegion region = MKCoordinateRegionMake(self.currentLocation.coordinate, span);
  [self.mapView setRegion:region animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  NSLog(@"%@, %@", error.localizedDescription, error.localizedFailureReason);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  // called each time with the status
  NSLog(@"%@: %@", @(__LINE__), @(status)); // 0 is not determined
  if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
    [manager requestLocation];
  }
}

#pragma mark - Cafes Setter

- (void)setCafes:(NSArray<MKAnnotation> *)cafes {
  
  _cafes = cafes;
  [self.mapView addAnnotations:cafes];
  [self.mapView showAnnotations:cafes animated:YES];
}


@end

