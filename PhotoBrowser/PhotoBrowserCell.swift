//
//  PhotoBrowserCell.swift
//  PhotoBrowser
//
//  Created by JiongXing on 2017/3/28.
//  Copyright © 2017年 JiongXing. All rights reserved.
//

import UIKit
import YYWebImage

protocol PhotoBrowserCellDelegate: NSObjectProtocol {
    /// 单击时回调
    func photoBrowserCellDidSingleTap(_ cell: PhotoBrowserCell)
    
    /// 拖动时回调。scale:缩放比率
    func photoBrowserCell(_ cell: PhotoBrowserCell, didPanScale scale: CGFloat)
    
    /// 长按时回调
    func photoBrowserCell(_ cell: PhotoBrowserCell, didLongPressWith image: UIImage)
}

public class PhotoBrowserCell: UICollectionViewCell {
    // MARK: - 公开属性
    /// 代理
    weak var photoBrowserCellDelegate: PhotoBrowserCellDelegate?
    
    /// 显示图像(支持动画)
    public let imageView = YYAnimatedImageView()
    
    /// 原图url
    public var rawUrl: URL?
    
    /// 捏合手势放大图片时的最大允许比例
    public var imageMaximumZoomScale: CGFloat = 2.0 {
        didSet {
            self.scrollView.maximumZoomScale = imageMaximumZoomScale
        }
    }
    
    /// 双击放大图片时的目标比例
    public var imageZoomScaleForDoubleTap: CGFloat = 2.0
    
    public var photoSpacing: CGFloat = 30
    
    // MARK: - 内部属性
    /// 内嵌容器。本类不能继承UIScrollView。
    /// 因为实测UIScrollView遵循了UIGestureRecognizerDelegate协议，而本类也需要遵循此协议，
    /// 若继承UIScrollView则会覆盖UIScrollView的协议实现，故只内嵌而不继承。
    private let scrollView = UIScrollView()
    
    /// 加载进度指示器
    private let progressView = PhotoBrowserProgressView()
    
    private var progressViewShowCount = 0
    
    weak var browser:PhotoBrowser?
    
    /// 查看原图按钮
    private lazy var rawImageButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        button.addTarget(self, action: #selector(onRawImageButtonTap), for: .touchUpInside)
        button.setBackgroundImage(rawImageButtonBackgroundImage, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
        return button
        }()
    
    private lazy var rawImageCancelView: UIImageView = { [unowned self] in
        guard let bundle = browser?.bundle, let img = UIImage(named: "cancel", in: bundle, compatibleWith: nil) else {
            return UIImageView()
        }
        
        let view = UIImageView(image: img)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.bounds.size = CGSize(width: 8, height: 8)
        
        rawImageButton.addSubview(view)
        return view
        }()
    
    private lazy var rawImageButtonBackgroundImage: UIImage? = { [unowned self] in
        guard let bundle = browser?.bundle else {
            return nil
        }
        let img = UIImage(named: "rawbtn", in: bundle, compatibleWith: nil)
        let edge = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        return img?.resizableImage(withCapInsets: edge, resizingMode: .tile)
        }()
    
    private var rawImageButtonSize: CGSize? = nil
    
    /// 计算contentSize应处于的中心位置
    private var centerOfContentSize: CGPoint {
        let deltaWidth = scrollView.bounds.width - scrollView.contentSize.width
        let offsetX = deltaWidth > 0 ? deltaWidth * 0.5 : 0
        let deltaHeight = scrollView.bounds.height - scrollView.contentSize.height
        let offsetY = deltaHeight > 0 ? deltaHeight * 0.5 : 0
        return CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                       y: scrollView.contentSize.height * 0.5 + offsetY)
    }
    
    /// 取图片适屏size
    private var fitSize: CGSize {
        guard let image = imageView.image else {
            return CGSize.zero
        }
        let width = scrollView.bounds.width
        let scale = image.size.height / image.size.width
        return CGSize(width: width, height: scale * width)
    }
    
    /// 取图片适屏frame
    private var fitFrame: CGRect {
        let size = fitSize
        let y = (scrollView.bounds.height - size.height) > 0 ? (scrollView.bounds.height - size.height) * 0.5 : 0
        return CGRect(x: 0, y: y, width: size.width, height: size.height)
    }
    
    /// 记录pan手势开始时imageView的位置
    private var beganFrame = CGRect.zero
    
    /// 记录pan手势开始时，手势位置
    private var beganTouch = CGPoint.zero

    private var shouldLayout = true
    
    /// 是否正在下载原图
    private var rawImageDownloading = false {
        didSet {
            rawImageCancelView.isHidden = !rawImageDownloading
        }
    }
    
    /// 原图大小
    private var rawSize:Int? = nil
    
    // MARK: - 方法
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.maximumZoomScale = imageMaximumZoomScale
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.isMultipleTouchEnabled = true
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }

        scrollView.addSubview(imageView)
        imageView.clipsToBounds = true
        
        contentView.addSubview(progressView)
        progressView.isHidden = true
        
        // 长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        contentView.addGestureRecognizer(longPress)
        
        // 双击手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        contentView.addGestureRecognizer(doubleTap)
        
        // 单击手势
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(onSingleTap))
        contentView.addGestureRecognizer(singleTap)
        singleTap.require(toFail: doubleTap)
        
        // 拖动手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        scrollView.addGestureRecognizer(pan)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.yy_cancelCurrentImageRequest()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        doLayout()
    }
    
    /// 布局
    private func doLayout() {
        guard shouldLayout else { return }

        scrollView.frame = CGRect(x: photoSpacing/2, y: 0,
                                  width: contentView.bounds.width - photoSpacing,
                                  height: contentView.bounds.height)
        scrollView.setZoomScale(1.0, animated: false)
        imageView.frame = fitFrame
        scrollView.setZoomScale(1.0, animated: false)
        progressView.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        
        // 查看原图按钮
        if rawImageButton.isHidden == false {
            contentView.addSubview(rawImageButton)
            if rawImageButtonSize == nil {
                rawImageButton.sizeToFit()
                if rawImageButton.bounds.width < 110 {
                    rawImageButton.bounds.size.width = 110
                }
                if rawImageButton.bounds.height < 26 {
                    rawImageButton.bounds.size.height = 26
                }
                rawImageButtonSize = rawImageButton.bounds.size
            } else {
                rawImageButton.bounds.size = rawImageButtonSize!
            }
            
            var center:CGPoint!
            var bottomY:CGFloat = 6 + UIPageControlHeight + UIPageControlBottom
            if #available(iOS 11.0, *) {
                let safeAreaInsets = superview?.safeAreaInsets ?? UIEdgeInsets.zero
                if safeAreaInsets.bottom > 0 {
                    bottomY = 6 + UIPageControlHeight
                }
                let bounds = UIEdgeInsetsInsetRect(contentView.bounds, safeAreaInsets)
                center = CGPoint(x: bounds.midX, y: bounds.maxY - bottomY - rawImageButton.bounds.height / 2)
            } else {
                center = CGPoint(x: contentView.bounds.midX,
                                 y: contentView.bounds.maxY - bottomY - rawImageButton.bounds.height / 2)
            }
            rawImageButton.center = center
            rawImageCancelView.center = CGPoint(x: rawImageButton.bounds.maxX - 12 - rawImageCancelView.bounds.width / 2,
                                                y: rawImageButton.bounds.maxY / 2)
        }
    }
    
    private func resetRawImageButton() {
        guard let languageBundle = browser?.languageBundle else {
            return
        }
        //设置查看原图按钮的标题
        var sizeTitle = ""
        if let size = rawSize {
            if size < 1024*1024 {
                //形如(367K)
                sizeTitle = "(\(Int(size / 1024))K)"
            } else {
                //形如(11.3M)，保留一位小数
                sizeTitle = String(format: "(%.1fM)", Double(size) / 1024 / 1024)
            }
        }
        let fullImageTitle = languageBundle.localizedString(forKey: "查看原图", value: nil, table: nil)
        rawImageButton.setTitle("\(fullImageTitle) \(sizeTitle)", for: .normal)
        rawImageButtonSize = nil
    }
    
    /// 设置图片。image为placeholder图片，url为网络图片
    public func setImage(_ image: UIImage?, highQualityUrl: URL?, rawUrl: URL?, rawSize: Int?) {
        // 查看原图按钮
        if rawImageDownloading {
            rawImageDownloading = false
            imageView.yy_cancelCurrentImageRequest()
        }
        
        self.rawUrl = rawUrl
        self.rawSize = rawSize
        if let url = rawUrl,
            highQualityUrl?.absoluteString.compare(url.absoluteString) == .orderedSame {
            //特例，如果高清图和原图地址相同，那么忽略原图url
            self.rawUrl = nil
        }
        
        rawImageButton.isHidden = (self.rawUrl == nil)
        resetRawImageButton()
        
        // 取placeholder图像，默认使用传入的缩略图
        var placeholder = image
        // 若已有原图缓存，优先使用原图
        // 次之使用高清图
        var url = highQualityUrl
        if let cacheImage = imageFor(url: self.rawUrl) {
            placeholder = cacheImage
            url = self.rawUrl
            rawImageButton.isHidden = true
        } else if let cacheImage = imageFor(url: highQualityUrl) {
            placeholder = cacheImage
        }
        // 处理只配置了原图而不配置高清图的情况。此时使用原图代替高清图作为下载url
        if url == nil {
            url = self.rawUrl
        }
        guard url != nil else {
            imageView.image = image
            doLayout()
            return
        }
        loadImage(withPlaceholder: placeholder, url: url)
        self.doLayout()
    }
    
    /// 加载图片
    private func loadImage(withPlaceholder placeholder: UIImage?, url: URL?) {
        self.progressViewShowCount += 1
        self.progressView.isHidden = false
        imageView.yy_setImage(
            with: url, placeholder: placeholder, options: [],
            progress: { [weak self] (receivedSize, totalSize) in
                if totalSize > 0 {
                    let progress = CGFloat(receivedSize) / CGFloat(totalSize)
                    self?.progressView.progress = max(progress, 0.02)
                    if self?.rawImageDownloading == true {
                        self?.rawImageButton.setTitle("\(Int(progress*100))%", for: .normal)
                    }
                }
        }, transform: nil, completion: { [weak self] (image,_,from,_,_) in
            guard let `self` = self else {
                return
            }
            if self.rawImageDownloading {
                self.rawImageDownloading = false
                if image == nil {
                    //原图加载失败，按钮文本恢复为“查看原图(367KB)”
                    self.resetRawImageButton()
                } else {
                    //原图加载成功，渐隐按钮
                    guard let languageBundle = self.browser?.languageBundle else {
                        return
                    }
                    let doneTitle = languageBundle.localizedString(forKey: "已完成", value: nil, table: nil)
                    self.rawImageButton.setTitle(doneTitle, for: .normal)
                    UIView.animate(withDuration: 0.5, animations: {
                        self.rawImageButton.alpha = 0
                    }, completion: { _ in
                        self.rawImageButton.isHidden = true
                        self.rawImageButton.alpha = 1
                    })
                }
            }
            self.progressViewShowCount -= 1
            //因为可能会多次重复调用yy_setImage，所以弄一个计数器
            if self.progressViewShowCount == 0 {
                if from == .remote {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.progressView.alpha = 0
                    }, completion: { _ in
                        self.progressView.isHidden = true
                        self.progressView.alpha = 1
                    })
                } else {
                    //如果不是从网络下载来的，那么直接隐藏进度
                    self.progressView.isHidden = true
                }
            }
            if image != nil {
                self.doLayout()
            }
        })
    }
    
    /// 根据url从缓存取图像
    private func imageFor(url: URL?) -> UIImage? {
        guard let url = url else {
            return nil
        }
        let manager = YYWebImageManager.shared()
        //TODO: 需考虑disk阻塞问题
        return manager.cache?.getImageForKey(manager.cacheKey(for: url), with: .all)
    }
    
    /// 响应单击
    @objc func onSingleTap() {
        if let dlg = photoBrowserCellDelegate {
            dlg.photoBrowserCellDidSingleTap(self)
        }
    }
    
    /// 响应双击
    @objc func onDoubleTap(_ dbTap: UITapGestureRecognizer) {
        // 如果当前没有任何缩放，则放大到目标比例
        // 否则重置到原比例
        if scrollView.zoomScale == 1.0 {
            // 以点击的位置为中心，放大
            let pointInView = dbTap.location(in: imageView)
            let w = scrollView.bounds.size.width / imageZoomScaleForDoubleTap
            let h = scrollView.bounds.size.height / imageZoomScaleForDoubleTap
            let x = pointInView.x - (w / 2.0)
            let y = pointInView.y - (h / 2.0)
            scrollView.zoom(to: CGRect(x: x, y: y, width: w, height: h), animated: true)
        } else {
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    /// 响应拖动
    @objc func onPan(_ pan: UIPanGestureRecognizer) {
        guard imageView.image != nil else {
            return
        }

        var results: (CGRect, CGFloat) {
            // 拖动偏移量
            let translation = pan.translation(in: scrollView)
            let currentTouch = pan.location(in: scrollView)

            // 由下拉的偏移值决定缩放比例，越往下偏移，缩得越小。scale值区间[0.3, 1.0]
            let scale = min(1.0, max(0.3, 1 - translation.y / bounds.height))

            let width = beganFrame.size.width * scale
            let height = beganFrame.size.height * scale

            // 计算x和y。保持手指在图片上的相对位置不变。
            // 即如果手势开始时，手指在图片X轴三分之一处，那么在移动图片时，保持手指始终位于图片X轴的三分之一处
            let xRate = (beganTouch.x - beganFrame.origin.x) / beganFrame.size.width
            let currentTouchDeltaX = xRate * width
            let x = currentTouch.x - currentTouchDeltaX

            let yRate = (beganTouch.y - beganFrame.origin.y) / beganFrame.size.height
            let currentTouchDeltaY = yRate * height
            let y = currentTouch.y - currentTouchDeltaY

            return (CGRect(x: x, y: y, width: width, height: height), scale)
        }

        switch pan.state {
        case .began:
            beganFrame = imageView.frame
            beganTouch = pan.location(in: scrollView)
        case .changed:
            let r = results
            imageView.frame = r.0

            // 通知代理，发生了缩放。代理可依scale值改变背景蒙板alpha值
            if let dlg = photoBrowserCellDelegate {
                dlg.photoBrowserCell(self, didPanScale: r.1)
            }
        case .ended, .cancelled:
            if pan.velocity(in: self).y > 0 {
                // dismiss
                shouldLayout = false
                imageView.frame = results.0
                onSingleTap()
            } else {
                // 取消dismiss
                endPan()
            }
        default:
            endPan()
        }
    }
    
    private func endPan() {
        if let dlg = photoBrowserCellDelegate {
            dlg.photoBrowserCell(self, didPanScale: 1.0)
        }
        // 如果图片当前显示的size小于原size，则重置为原size
        let size = fitSize
        let needResetSize = imageView.bounds.size.width < size.width
            || imageView.bounds.size.height < size.height
        UIView.animate(withDuration: 0.25) {
            self.imageView.center = self.centerOfContentSize
            if needResetSize {
                self.imageView.bounds.size = size
            }
        }
    }
    
    /// 响应长按
    @objc func onLongPress(_ press: UILongPressGestureRecognizer) {
        if press.state == .began, let dlg = photoBrowserCellDelegate, let image = imageView.image {
            dlg.photoBrowserCell(self, didLongPressWith: image)
        }
    }
    
    /// 响应查看原图按钮
    @objc func onRawImageButtonTap() {
        if !rawImageDownloading {
            rawImageDownloading = true
            progressView.progress = 0.02
            rawImageButton.setTitle("0%", for: .normal)
            loadImage(withPlaceholder: imageView.image, url: rawUrl)
        } else {
            //取消下载
            rawImageDownloading = false
            imageView.yy_cancelCurrentImageRequest()
            resetRawImageButton()
        }
    }
}

extension PhotoBrowserCell: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        imageView.center = centerOfContentSize
    }
}

extension PhotoBrowserCell: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只响应pan手势
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = pan.velocity(in: self)
        // 向上滑动时，不响应手势
        if velocity.y < 0 {
            return false
        }
        // 横向滑动时，不响应pan手势
        if abs(Int(velocity.x)) > Int(velocity.y) {
            return false
        }
        // 向下滑动，如果图片顶部超出可视区域，不响应手势
        if scrollView.contentOffset.y > 0 {
            return false
        }
        return true
    }
}
