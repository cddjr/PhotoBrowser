//
//  PhotoBrowserDefaultPageControlDelegate.swift
//  PhotoBrowser
//
//  Created by JiongXing on 2017/4/25.
//  Copyright © 2017年 JiongXing. All rights reserved.
//

import UIKit

/// 给图片浏览器提供一个UIPageControl
public class PhotoBrowserDefaultPageControlDelegate: PhotoBrowserPageControlDelegate {
    /// 总页数
    public var numberOfPages: Int
    
    /// 底部Y坐标
    public var bottomY: CGFloat = 6
    
    public init(numberOfPages: Int) {
        self.numberOfPages = numberOfPages
    }
    
    public func pageControlOfPhotoBrowser(_ photoBrowser: PhotoBrowser) -> UIView {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = numberOfPages
        return pageControl
    }
    
    public func photoBrowserPageControl(_ pageControl: UIView, didMoveTo superView: UIView) {
        // 这里可以不作任何操作
    }
    
    public func photoBrowserPageControl(_ pageControl: UIView, needLayoutIn superView: UIView) {
        pageControl.sizeToFit()
        var center:CGPoint!
        if #available(iOS 11.0, *) {
            var bottomY = self.bottomY
            if superView.safeAreaInsets.bottom > 0 {
                bottomY = 0
            }
            let bounds = UIEdgeInsetsInsetRect(superView.bounds, superView.safeAreaInsets)
            center = CGPoint(x: bounds.midX, y: bounds.maxY - bottomY - pageControl.bounds.height / 2)
        } else {
            center = CGPoint(x: superView.bounds.midX, y: superView.bounds.maxY - bottomY - pageControl.bounds.height / 2)
        }
        pageControl.center = center
    }
    
    public func photoBrowserPageControl(_ pageControl: UIView, didChangedCurrentPage currentPage: Int) {
        guard let pageControl = pageControl as? UIPageControl else {
            return
        }
        pageControl.currentPage = currentPage
    }
}
