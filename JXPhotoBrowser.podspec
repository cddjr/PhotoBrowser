Pod::Spec.new do |s|
  s.name = 'JXPhotoBrowser'
  s.version = '0.4.5'
  s.license = 'MIT'
  s.summary = 'Elegant photo browser in Swift.'
  s.homepage = 'https://github.com/JiongXing/PhotoBrowser'
  s.authors = { 'JiongXing' => '549235261@qq.com' }
  s.source = { :git => 'https://github.com/JiongXing/PhotoBrowser.git', :tag => s.version }
  s.source_files  = 'PhotoBrowser/*.swift'
  s.resource_bundles = {'JXPhotoBrowser' => ['PhotoBrowser/Resources/**/*']}
  s.ios.deployment_target = '8.0'
  s.dependency 'YYWebImage'
end
