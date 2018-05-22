//
//  EditorViewController.swift
//  ShaderPlayground
//
//  Created by TakatsuYouichi on 2018/04/15.
//  Copyright © 2018年 TakatsuYouichi. All rights reserved.
//

import UIKit
import Metal

class EditorViewController: UIViewController {

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textView: UITextView!
    var compiledLibrary:MTLLibrary? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let sourcePath = Bundle.main.path(forResource: "ShaderSource", ofType: "txt") else {
            return
        }
        let sourceUrl = URL(fileURLWithPath: sourcePath)
        self.textView.text = try! String(contentsOf: sourceUrl, encoding: .utf8)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setObservers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.removeObservers()
    }
    
    func setObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object:nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidHide(notification:)), name: NSNotification.Name.UIKeyboardDidHide, object:nil)
    }
    
    func removeObservers() {
        let notificationCenter = NotificationCenter.default;
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }
    
    @objc func keyboardDidShow(notification:Notification) {
        guard let keyboardHeihgt = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.height else {
            return
        }
        self.bottomConstraint.constant = -keyboardHeihgt
    }
    
    @objc func keyboardDidHide(notification:Notification) {
        guard let keyboardHeight = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height else {
            return
        }
        self.bottomConstraint.constant = -keyboardHeight
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func compileAndRun(_ sender: UIBarButtonItem) {
        do {
            compiledLibrary = try MTLCreateSystemDefaultDevice()?.makeLibrary(source: textView.text, options: nil)
        }
        catch let error {
            let alert = UIAlertController(title: "ERROR", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        performSegue(withIdentifier: "compileRunSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let viewController = segue.destination as! ViewController
        viewController.compiledLibrary = self.compiledLibrary;
    }
}
