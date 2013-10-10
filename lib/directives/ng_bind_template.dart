part of angular.directive;

@NgDirective(
  selector: '[ng-bind-template]',
  map: const {'ng-bind-template': '@.bind'})
class NgBindTemplateDirective {
  dom.Element element;

  NgBindTemplateDirective(dom.Element this.element);

  set bind(value) {
    element.text = value;
  }
}
