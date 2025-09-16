document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('container');
    const categoryView = document.getElementById('category-view');
    const optionView = document.getElementById('option-view');
    const callsignView = document.getElementById('callsign-view');
    const categoryList = document.getElementById('category-list');
    const optionList = document.getElementById('option-list');
    const optionTitle = document.getElementById('option-title');
    const callsignInput = document.getElementById('callsign-input');
    const setCallsignButton = document.getElementById('set-callsign-button');
    const backButtons = document.querySelectorAll('.back-button');

    let currentView = 'categories'; 
    let categoriesData = null;
    let activeCategoryKey = null;
    let selectedIndices = {
        categories: 0,
        options: 0,
    };

    const post = (event, data = {}) => {
        const resourceName = window.GetParentResourceName();
    
        fetch(`https://${resourceName}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).catch(err => console.error(`Failed to post to ${event}:`, err));
    };

    const renderCategories = (order) => { 
        categoryList.innerHTML = '';
    
        order.forEach(key => { 
            const category = categoriesData[key];
            if (category) {
                const li = document.createElement('li');
                li.textContent = category.displayName;
                li.dataset.key = key;
                li.addEventListener('click', () => {
                    if (category.type === 'input') {
                        showCallsignInput();
                    } else {
                        showOptions(key);
                    }
                });
                categoryList.appendChild(li);
            }
        });
        updateSelectionVisuals();
    };

    const renderOptions = (categoryKey) => {
        const category = categoriesData[categoryKey];
        optionList.innerHTML = '';
        optionTitle.textContent = category.displayName;
        
        let initialIndex = 0;
        category.options.forEach((opt, i) => {
            const li = document.createElement('li');
            li.textContent = opt.name;
            li.dataset.modType = category.modType;
            li.dataset.index = opt.index;
            if (opt.index === category.currentIndex) {
                initialIndex = i;
            }
            li.addEventListener('click', () => {
                post('select', { modType: li.dataset.modType, index: li.dataset.index });
                categoriesData[activeCategoryKey].currentIndex = parseInt(li.dataset.index, 10);
                selectedIndices.options = i;
                updateSelectionVisuals();
            });
            optionList.appendChild(li);
        });
        selectedIndices.options = initialIndex;
        updateSelectionVisuals();
    };

    const showCategories = () => {
        currentView = 'categories';
        optionView.classList.add('hidden');
        callsignView.classList.add('hidden');
        categoryView.classList.remove('hidden');
        callsignInput.value = "";
        updateSelectionVisuals();
    };

    const showOptions = (categoryKey) => {
        activeCategoryKey = categoryKey;
        currentView = 'options';
        categoryView.classList.add('hidden');
        optionView.classList.remove('hidden');
        renderOptions(categoryKey);
    };

    const showCallsignInput = () => {
        currentView = 'callsign';
        categoryView.classList.add('hidden');
        callsignView.classList.remove('hidden');
        callsignInput.focus();
    };

    const updateSelectionVisuals = (isInitialRender = false) => {
        if (currentView === 'callsign') return;
        const list = currentView === 'categories' ? categoryList : optionList;
        const index = selectedIndices[currentView];
        const items = list.getElementsByTagName('li');
        if (items.length === 0) return;
    
        Array.from(items).forEach(item => item.classList.remove('selected'));
        const selectedItem = items[index];
        if (selectedItem) {
            selectedItem.classList.add('selected');
            const behavior = isInitialRender ? 'auto' : 'smooth';
            selectedItem.scrollIntoView({ block: 'nearest', behavior });
        }
    };
    
    const handleConfirm = () => {
        if (currentView === 'categories') {
            const item = categoryList.getElementsByTagName('li')[selectedIndices.categories];
            if (item) item.click();
        } else if (currentView === 'options') {
            const item = optionList.getElementsByTagName('li')[selectedIndices.options];
            if (item) item.click();
        } else if (currentView === 'callsign') {
            setCallsignButton.click();
        }
    };
    
    const handleBack = () => {
        if (currentView === 'options' || currentView === 'callsign') {
            showCategories();
        } else {
            post('close');
        }
    };

    const handleNavigation = (direction) => {
        if (currentView !== 'categories' && currentView !== 'options') return;
        
        const list = currentView === 'categories' ? categoryList : optionList;
        const items = list.getElementsByTagName('li');
        if (items.length === 0) return;

        const currentIndex = selectedIndices[currentView];
        const newIndex = (currentIndex + direction + items.length) % items.length;
        selectedIndices[currentView] = newIndex;
        updateSelectionVisuals();
    };

    window.addEventListener('message', (event) => {
        const { action, categories, categoryOrder } = event.data; 
        if (action === 'display') {
            container.style.display = 'block'; 
            categoriesData = categories;
            renderCategories(categoryOrder);
        } else if (action === 'hide') {
            container.style.display = 'none';
        }
    });

    document.addEventListener('keydown', (e) => {
        if (container.style.display === 'none') return;
        
        switch (e.key) {
            case 'ArrowDown':
                handleNavigation(1);
                e.preventDefault();
                break;
            case 'ArrowUp':
                handleNavigation(-1);
                e.preventDefault();
                break;
            case 'ArrowRight':
            case 'Enter':
                handleConfirm();
                e.preventDefault();
                break;
            case 'Escape':
                handleBack();
                e.preventDefault();
                break;
            case 'Backspace':
                if (document.activeElement !== callsignInput) {
                    handleBack();
                    e.preventDefault();
                }
                break;
        }
    });
    
    backButtons.forEach(button => button.addEventListener('click', handleBack));

    setCallsignButton.addEventListener('click', () => {
        post('setCallsign', { callsign: callsignInput.value });
        showCategories();
    });
});