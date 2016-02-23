# simple-coverflow

DISCLAIMER: code may contain external classes and categories
A very simple and limited coverflow-like UI component

        self.view.backgroundColor = UIColor(hex: "191919")
        
        self.coverflowView = CoverflowView(viewContent: UIImageView(image: UIImage(named:"image1")))
        self.coverflowView.delegate = self
        self.view.addSubview(self.coverflowView)
  
        self.coverflowView.nextViewContent = UIImageView(image: UIImage(named:"image2"))
        self.coverflowView.headingText = "Top title"
        self.coverflowView.contentText = "Bottom description"
        
After you set the nextViewContent, and when user is ready to see the next content, call:

        self.coverflowView.presentNext()
        
Implement delegate methods for touch callbacks.
